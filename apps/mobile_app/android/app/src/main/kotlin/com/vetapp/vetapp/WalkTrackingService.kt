package com.vetapp.vetapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Foreground service that keeps the app process "in use" while a walk is
 * tracked, so GPS keeps flowing with the screen off or another app on top
 * (owner report, 2026-10-07). Its notification is the walk's status in the
 * shade: "Passeggiata con <pet>", distance, a system-ticked chronometer, and
 * Pausa/Riprendi + Termina actions.
 *
 * Replaces geolocator's own foreground notification, whose channel the plugin
 * creates with IMPORTANCE_NONE - most phones never show it, and a channel's
 * importance can't be raised once created. GPS itself still comes from
 * geolocator's plain position stream (active_walk_controller.dart).
 *
 * Driven from Dart over [CHANNEL] (walk_foreground_service.dart): `start`
 * once per walk while the app is visible (Android 12+ refuses to start a
 * foreground service from the background), `update` for every change after
 * that - including pause/resume from the widget with the app in background,
 * which only re-posts the notification - and `stop` when the walk ends.
 */
class WalkTrackingService : Service() {
  companion object {
    const val CHANNEL = "vetapp/walk_tracking_service"
    private const val TAG = "WalkTrackingService"

    /** Shared with nobody: the "Notifiche" session's reminders use their own channels. */
    private const val NOTIFICATION_CHANNEL_ID = "vetapp_walk_tracking"
    private const val NOTIFICATION_ID = 7307

    private const val EXTRA_PET_ID = "petId"
    private const val EXTRA_TITLE = "title"
    private const val EXTRA_TEXT = "text"
    private const val EXTRA_PAUSED = "paused"
    private const val EXTRA_CHRONOMETER_BASE = "chronometerBaseMillis"

    @Volatile var isRunning = false
      private set

    /**
     * Starts the service in the foreground. False when Android refused (for
     * instance the app is not visible) - Dart then falls back to geolocator's
     * own notification so tracking still survives the background.
     */
    fun start(context: Context, args: Map<*, *>): Boolean {
      val intent = Intent(context, WalkTrackingService::class.java).apply { putArgs(args) }
      return try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          context.startForegroundService(intent)
        } else {
          context.startService(intent)
        }
        true
      } catch (error: Exception) {
        Log.w(TAG, "Could not start the walk foreground service", error)
        false
      }
    }

    /** Re-posts the notification in place; no-op when the service isn't running. */
    fun update(context: Context, args: Map<*, *>) {
      if (!isRunning) return
      val intent = Intent().apply { putArgs(args) }
      notificationManager(context).notify(NOTIFICATION_ID, buildNotification(context, intent))
    }

    fun stop(context: Context) {
      context.stopService(Intent(context, WalkTrackingService::class.java))
    }

    private fun Intent.putArgs(args: Map<*, *>) {
      putExtra(EXTRA_PET_ID, args[EXTRA_PET_ID] as? String ?: "")
      putExtra(EXTRA_TITLE, args[EXTRA_TITLE] as? String ?: "Passeggiata in corso")
      putExtra(EXTRA_TEXT, args[EXTRA_TEXT] as? String ?: "")
      putExtra(EXTRA_PAUSED, args[EXTRA_PAUSED] as? Boolean ?: false)
      putExtra(EXTRA_CHRONOMETER_BASE, (args[EXTRA_CHRONOMETER_BASE] as? Number)?.toLong() ?: 0L)
    }

    private fun notificationManager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    /**
     * IMPORTANCE_DEFAULT keeps the walk among the top ("alerting") notifications
     * instead of the silent section at the bottom; sound and vibration are
     * switched off on the channel, so posting and re-posting it is quiet.
     */
    private fun ensureChannel(context: Context) {
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
      val manager = notificationManager(context)
      if (manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) != null) return
      val channel = NotificationChannel(
          NOTIFICATION_CHANNEL_ID,
          "Passeggiata in corso",
          NotificationManager.IMPORTANCE_DEFAULT,
      ).apply {
        description = "Mostra la passeggiata in corso: tempo, distanza, pausa e fine."
        setSound(null, null)
        enableVibration(false)
        setShowBadge(false)
      }
      manager.createNotificationChannel(channel)
    }

    // Text-only buttons: the int-icon builder works on every API level the app supports.
    @Suppress("DEPRECATION")
    private fun action(label: String, intent: PendingIntent): Notification.Action =
        Notification.Action.Builder(0, label, intent).build()

    private fun buildNotification(context: Context, intent: Intent): Notification {
      ensureChannel(context)
      val petId = intent.getStringExtra(EXTRA_PET_ID) ?: ""
      val paused = intent.getBooleanExtra(EXTRA_PAUSED, false)
      val chronometerBase = intent.getLongExtra(EXTRA_CHRONOMETER_BASE, 0L)

      val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        Notification.Builder(context, NOTIFICATION_CHANNEL_ID)
      } else {
        @Suppress("DEPRECATION")
        Notification.Builder(context)
      }
      builder
          .setSmallIcon(R.drawable.ic_stat_walk)
          .setContentTitle(intent.getStringExtra(EXTRA_TITLE))
          .setContentText(intent.getStringExtra(EXTRA_TEXT))
          .setOngoing(true)
          .setOnlyAlertOnce(true)
          .setCategory(Notification.CATEGORY_SERVICE)
          .setColor(0xFF2E686A.toInt())
          .setVisibility(Notification.VISIBILITY_PUBLIC)

      // Running: the system ticks the elapsed time itself from this base, so
      // Dart only re-posts when the distance or the paused state changes.
      if (!paused && chronometerBase > 0) {
        builder.setWhen(chronometerBase).setUsesChronometer(true).setShowWhen(true)
      } else {
        builder.setShowWhen(false)
      }

      if (petId.isNotEmpty()) {
        // Same targets as the home-screen widget's pills, so walk_home_widget.dart
        // handles them: tap -> open the walk, Pausa/Riprendi -> live isolate
        // without opening the app, Termina -> app opens on the finish flow.
        builder.setContentIntent(DogWalksWidgetProvider.actionIntent(context, "open_walk", petId))
        val command = if (paused) "resume" else "pause"
        builder.addAction(
            action(
                if (paused) "Riprendi" else "Pausa",
                DogWalksWidgetProvider.controlBroadcast(context, command, petId),
            )
        )
        builder.addAction(
            action("Termina", DogWalksWidgetProvider.actionIntent(context, "finish_walk", petId))
        )
      }

      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        // Show it at once instead of after Android 12's 10-second grace delay.
        builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
      }
      return builder.build()
    }
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    val notification = buildNotification(this, intent ?: Intent())
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
      } else {
        startForeground(NOTIFICATION_ID, notification)
      }
      isRunning = true
    } catch (error: Exception) {
      // E.g. location permission revoked meanwhile (Android 14 requires it).
      Log.w(TAG, "startForeground refused", error)
      isRunning = false
      stopSelf()
    }
    // Not sticky: without the Flutter engine there is nothing to track, and a
    // walk interrupted by a process kill is offered back on the next launch.
    return START_NOT_STICKY
  }

  /**
   * The owner swiped the app away from Recents: the activity, its Flutter
   * engine and the GPS stream are gone, so don't leave a notification
   * advertising a walk nobody is tracking.
   */
  override fun onTaskRemoved(rootIntent: Intent?) {
    DogWalksWidgetProvider.clearActiveWalk(applicationContext)
    stopSelf()
    super.onTaskRemoved(rootIntent)
  }

  override fun onDestroy() {
    isRunning = false
    super.onDestroy()
  }
}
