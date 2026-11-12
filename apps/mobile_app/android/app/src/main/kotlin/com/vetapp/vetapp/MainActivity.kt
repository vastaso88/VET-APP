package com.vetapp.vetapp

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Lets the home-screen widget's pause/resume pill reach the live Dart isolate
 * (walk_home_widget.dart -> ActiveWalkController) without opening the app.
 * The widget provider and the activity share one process, so a static handle
 * to the main engine's channel is enough: it exists exactly while a Flutter
 * engine (and therefore the walk tracker) is alive.
 */
object WalkWidgetBridge {
  const val CHANNEL = "vetapp/home_widget_control"

  @Volatile private var channel: MethodChannel? = null

  val isAvailable: Boolean
    get() = channel != null

  fun attach(newChannel: MethodChannel?) {
    channel = newChannel
  }

  /** Sends `pause` / `resume` for [petId]; false when no engine is alive. */
  fun send(command: String, petId: String): Boolean {
    val current = channel ?: return false
    Handler(Looper.getMainLooper()).post {
      current.invokeMethod(command, petId)
    }
    return true
  }
}

class MainActivity : FlutterActivity() {
  companion object {
    private const val APP_NAVIGATION_CHANNEL = "vetapp/app_navigation"
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    // After the system killed the process and restores this Activity (e.g.
    // from Recents), Android replays the ORIGINAL launch intent. If that was a
    // home-screen widget tap, the plugin would report it to Dart again and
    // re-open the reminder form / walk the owner already handled. A restored
    // instance (savedInstanceState != null) never carries a fresh tap, so
    // drop the widget action before Flutter reads it.
    if (savedInstanceState != null &&
        intent?.action == HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION) {
      intent = Intent(Intent.ACTION_MAIN)
    }
    super.onCreate(savedInstanceState)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    WalkWidgetBridge.attach(
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WalkWidgetBridge.CHANNEL)
    )
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WalkTrackingService.CHANNEL)
        .setMethodCallHandler { call, result ->
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
          when (call.method) {
            "start" -> result.success(WalkTrackingService.start(applicationContext, args))
            "update" -> {
              WalkTrackingService.update(applicationContext, args)
              result.success(null)
            }
            "stop" -> {
              WalkTrackingService.stop(applicationContext)
              result.success(null)
            }
            else -> result.notImplemented()
          }
        }
    // Back on the shell's root page: send the app to the background like
    // Android 12+ does for launcher activities, instead of finishing the
    // activity - which used to kill the Flutter engine and so any walk being
    // tracked (owner report, 2026-10-07).
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_NAVIGATION_CHANNEL)
        .setMethodCallHandler { call, result ->
          if (call.method == "moveToBackground") {
            result.success(moveTaskToBack(true))
          } else if (call.method == "openNotificationSettings") {
            result.success(openNotificationSettings())
          } else {
            result.notImplemented()
          }
        }
  }

  /**
   * Opens this app's notification settings page (Android 8+), where the owner
   * can switch the notifications back on; false when the system has no such
   * screen, so Dart falls back to the app's general settings.
   */
  private fun openNotificationSettings(): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
    return try {
      startActivity(
          Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
              .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
              .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      )
      true
    } catch (_: Exception) {
      false
    }
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    WalkWidgetBridge.attach(null)
    super.cleanUpFlutterEngine(flutterEngine)
  }

  override fun onDestroy() {
    val finishing = isFinishing
    super.onDestroy()
    // The engine (and the walk tracking in it) dies with a finished activity:
    // stop advertising the walk on the widget and in the notification. A
    // walk recovered on the next launch is re-published by Dart.
    if (finishing) {
      DogWalksWidgetProvider.clearActiveWalk(applicationContext)
      WalkTrackingService.stop(applicationContext)
    }
  }
}
