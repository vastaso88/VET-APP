package com.vetapp.vetapp

import android.app.ActivityOptions
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * VetApp home-screen widget (owner request 2026-09-29, restyled and shrunk to
 * 4x1 on 2026-09-30): per pet an avatar and name, a "Nuovo promemoria" pill
 * and - dogs only - a "Passeggiata" pill.
 *
 * Two layouts, picked from the widget's current height ([TALL_MIN_HEIGHT_DP]):
 * a compact one-line strip (default, up to 2 pets + "+N altri") and the
 * original 4-row layout once the owner resizes the widget taller.
 *
 * Both pills deep-link into the app through home_widget's launch intent
 * (`homewidget://<action>?petId=...`), handled in walk_home_widget.dart:
 *  - `start_walk`   -> opens a new walk for the pet (active_walk_page.dart)
 *  - `new_reminder` -> opens the reminder creation form for the pet
 * walk_home_widget.dart also keeps [KEY_PETS] / [KEY_TOTAL] fresh via
 * `HomeWidget.saveWidgetData`.
 *
 * Active walk (owner request 2026-09-30): while [KEY_ACTIVE_WALK] is set
 * (walk_home_widget.dart mirrors ActiveWalkController into it, throttled) the
 * walking pet's row swaps the paw pill for a live "In corso/In pausa - km -
 * mm:ss" pill plus a pause/resume pill, hides the reminder pill to make room
 * and, in the compact layout, takes the whole strip (walking pet first, other
 * pets hidden). The mm:ss is a Chronometer, so it ticks with no widget
 * updates. Taps:
 *  - the row / status pill -> `open_walk` (opens ActiveWalkPage for the pet)
 *  - the pause/resume pill -> a broadcast to this provider; [WalkWidgetBridge]
 *    forwards it over a MethodChannel to the live Dart isolate, so the app is
 *    NOT brought to the foreground. If no Flutter engine is alive (process
 *    restarted, activity finished) the pill falls back to opening the app with
 *    `pause_walk` / `resume_walk`.
 */
class DogWalksWidgetProvider : HomeWidgetProvider() {

  private data class WidgetPet(
      val id: String,
      val name: String,
      val emoji: String,
      val isDog: Boolean,
      val color: Int,
  )

  /** Mirrors the JSON walk_home_widget.dart writes under [KEY_ACTIVE_WALK]. */
  private data class ActiveWalk(
      val petId: String,
      val paused: Boolean,
      val distanceLabel: String,
      val activeSeconds: Long,
      val updatedAtMs: Long,
  )

  private class RowIds(
      val slot: Int,
      val avatar: Int,
      val emoji: Int,
      val name: Int,
      val reminder: Int,
      val walk: Int,
      val status: Int,
      val pause: Int,
      val pauseIcon: Int,
  )

  private class LayoutSpec(
      val layout: Int,
      val root: Int,
      val empty: Int,
      val more: Int,
      val rows: List<RowIds>,
  )

  companion object {
    private const val KEY_PETS = "dog_walks_widget_pets"
    private const val KEY_TOTAL = "dog_walks_widget_total"
    const val KEY_ACTIVE_WALK = "dog_walks_widget_active_walk"

    /** Broadcast (to this provider) behind the pause/resume pill. */
    private const val ACTION_WALK_CONTROL = "com.vetapp.vetapp.WIDGET_WALK_CONTROL"
    private const val EXTRA_COMMAND = "command"
    private const val EXTRA_PET_ID = "petId"

    /**
     * Drops the active-walk data and redraws every widget. Called when the
     * activity finishes (engine and walk tracking die with it), so the widget
     * doesn't keep advertising a walk nobody is tracking any more.
     */
    fun clearActiveWalk(context: Context) {
      val prefs = HomeWidgetPlugin.getData(context)
      if (!prefs.contains(KEY_ACTIVE_WALK)) return
      prefs.edit().remove(KEY_ACTIVE_WALK).apply()
      val manager = AppWidgetManager.getInstance(context)
      val ids = manager.getAppWidgetIds(ComponentName(context, DogWalksWidgetProvider::class.java))
      if (ids.isEmpty()) return
      context.sendBroadcast(
          Intent(context, DogWalksWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
          }
      )
    }

    internal fun controlBroadcast(context: Context, command: String, petId: String): PendingIntent {
      val intent = Intent(context, DogWalksWidgetProvider::class.java).apply {
        action = ACTION_WALK_CONTROL
        putExtra(EXTRA_COMMAND, command)
        putExtra(EXTRA_PET_ID, petId)
      }
      return PendingIntent.getBroadcast(
          context,
          "broadcast:$command:$petId".hashCode(),
          intent,
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
    }

    /**
     * Same intent as home_widget's HomeWidgetLaunchIntent (LAUNCH action + data
     * URI, delivered to MainActivity and surfaced to Dart by the plugin), but
     * with a request code unique per (action, pet) instead of a constant 0, so
     * no two pills can ever share (and FLAG_UPDATE_CURRENT overwrite) one
     * PendingIntent.
     */
    internal fun actionIntent(context: Context, action: String, petId: String): PendingIntent {
      val intent = Intent(context, MainActivity::class.java).apply {
        this.action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
        data = Uri.parse("homewidget://$action?petId=${Uri.encode(petId)}")
      }
      val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      val requestCode = "$action:$petId".hashCode()

      if (Build.VERSION.SDK_INT < 34) {
        return PendingIntent.getActivity(context, requestCode, intent, flags)
      }
      val options = ActivityOptions.makeBasic()
      if (Build.VERSION.SDK_INT >= 35) {
        options.setPendingIntentCreatorBackgroundActivityStartMode(
            ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
        )
      } else {
        options.pendingIntentBackgroundActivityStartMode =
            ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
      }
      return PendingIntent.getActivity(context, requestCode, intent, flags, options.toBundle())
    }

    // AppColors.primary, used when the pet has no identity colour yet.
    private const val DEFAULT_COLOR = 0xFF2E686A.toInt()

    // ~3 home-screen cells (70dp*3-30dp = 180dp): from here up the 4-row
    // layout fits; below it the compact strip is used.
    private const val TALL_MIN_HEIGHT_DP = 170

    private val TALL = LayoutSpec(
        layout = R.layout.dog_walks_widget,
        root = R.id.dog_walks_widget_root,
        empty = R.id.dog_walks_widget_empty,
        more = R.id.dog_walks_widget_more,
        rows = listOf(
            RowIds(
                R.id.dog_walks_widget_slot_0, R.id.dog_walks_widget_avatar_0,
                R.id.dog_walks_widget_emoji_0, R.id.dog_walks_widget_name_0,
                R.id.dog_walks_widget_reminder_0, R.id.dog_walks_widget_walk_0,
                R.id.dog_walks_widget_status_0, R.id.dog_walks_widget_pause_0,
                R.id.dog_walks_widget_pause_icon_0,
            ),
            RowIds(
                R.id.dog_walks_widget_slot_1, R.id.dog_walks_widget_avatar_1,
                R.id.dog_walks_widget_emoji_1, R.id.dog_walks_widget_name_1,
                R.id.dog_walks_widget_reminder_1, R.id.dog_walks_widget_walk_1,
                R.id.dog_walks_widget_status_1, R.id.dog_walks_widget_pause_1,
                R.id.dog_walks_widget_pause_icon_1,
            ),
            RowIds(
                R.id.dog_walks_widget_slot_2, R.id.dog_walks_widget_avatar_2,
                R.id.dog_walks_widget_emoji_2, R.id.dog_walks_widget_name_2,
                R.id.dog_walks_widget_reminder_2, R.id.dog_walks_widget_walk_2,
                R.id.dog_walks_widget_status_2, R.id.dog_walks_widget_pause_2,
                R.id.dog_walks_widget_pause_icon_2,
            ),
            RowIds(
                R.id.dog_walks_widget_slot_3, R.id.dog_walks_widget_avatar_3,
                R.id.dog_walks_widget_emoji_3, R.id.dog_walks_widget_name_3,
                R.id.dog_walks_widget_reminder_3, R.id.dog_walks_widget_walk_3,
                R.id.dog_walks_widget_status_3, R.id.dog_walks_widget_pause_3,
                R.id.dog_walks_widget_pause_icon_3,
            ),
        ),
    )

    private val COMPACT = LayoutSpec(
        layout = R.layout.dog_walks_widget_compact,
        root = R.id.dog_walks_widget_c_root,
        empty = R.id.dog_walks_widget_c_empty,
        more = R.id.dog_walks_widget_c_more,
        rows = listOf(
            RowIds(
                R.id.dog_walks_widget_c_slot_0, R.id.dog_walks_widget_c_avatar_0,
                R.id.dog_walks_widget_c_emoji_0, R.id.dog_walks_widget_c_name_0,
                R.id.dog_walks_widget_c_reminder_0, R.id.dog_walks_widget_c_walk_0,
                R.id.dog_walks_widget_c_status_0, R.id.dog_walks_widget_c_pause_0,
                R.id.dog_walks_widget_c_pause_icon_0,
            ),
            RowIds(
                R.id.dog_walks_widget_c_slot_1, R.id.dog_walks_widget_c_avatar_1,
                R.id.dog_walks_widget_c_emoji_1, R.id.dog_walks_widget_c_name_1,
                R.id.dog_walks_widget_c_reminder_1, R.id.dog_walks_widget_c_walk_1,
                R.id.dog_walks_widget_c_status_1, R.id.dog_walks_widget_c_pause_1,
                R.id.dog_walks_widget_c_pause_icon_1,
            ),
        ),
    )
  }

  /** Pause/resume pill taps (see [controlBroadcast]) land here. */
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action == ACTION_WALK_CONTROL) {
      val command = intent.getStringExtra(EXTRA_COMMAND) ?: return
      val petId = intent.getStringExtra(EXTRA_PET_ID) ?: return
      if (!WalkWidgetBridge.send(command, petId)) {
        // No live Dart isolate: best-effort fallback to opening the app (the
        // background-activity-start rules may block this from a receiver).
        try {
          context.startActivity(
              Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = Uri.parse("homewidget://${command}_walk?petId=${Uri.encode(petId)}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
              }
          )
        } catch (_: Exception) {
        }
      }
      return
    }
    super.onReceive(context, intent)
  }

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { render(context, appWidgetManager, it, widgetData) }
  }

  /** Resizing across the height threshold swaps the compact/tall layout. */
  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle,
  ) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
  }

  private fun render(
      context: Context,
      appWidgetManager: AppWidgetManager,
      widgetId: Int,
      widgetData: SharedPreferences,
  ) {
    val heightDp = appWidgetManager
        .getAppWidgetOptions(widgetId)
        .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
    val spec = if (heightDp >= TALL_MIN_HEIGHT_DP) TALL else COMPACT

    val allPets = parsePets(widgetData.getString(KEY_PETS, null))
    val activeWalk = parseActiveWalk(widgetData.getString(KEY_ACTIVE_WALK, null))
        ?.takeIf { walk -> allPets.any { it.id == walk.petId } }
    val pets = if (activeWalk != null && spec === COMPACT) {
      // The strip is too narrow for the live walk pill next to a second pet:
      // the walking pet takes all of it.
      allPets.filter { it.id == activeWalk.petId }
    } else {
      allPets.take(spec.rows.size)
    }
    val total = maxOf(
        allPets.size,
        widgetData.getString(KEY_TOTAL, null)?.toIntOrNull() ?: 0,
    )
    val hidden = total - pets.size

    val views = RemoteViews(context.packageName, spec.layout)

    // Tapping anywhere that isn't a button (background, empty state, a
    // row's name/avatar, "+N altri") just opens the app.
    views.setOnClickPendingIntent(spec.root, openAppIntent(context))

    views.setViewVisibility(spec.empty, if (pets.isEmpty()) View.VISIBLE else View.GONE)
    if (hidden > 0) {
      views.setTextViewText(spec.more, context.getString(R.string.dog_walks_widget_more, hidden))
      views.setViewVisibility(spec.more, View.VISIBLE)
    } else {
      views.setViewVisibility(spec.more, View.GONE)
    }

    spec.rows.forEachIndexed { index, row ->
      val pet = pets.getOrNull(index)
      if (pet == null) {
        views.setViewVisibility(row.slot, View.GONE)
        return@forEachIndexed
      }

      views.setViewVisibility(row.slot, View.VISIBLE)
      views.setInt(row.avatar, "setColorFilter", pet.color)
      views.setTextViewText(row.emoji, pet.emoji)
      views.setTextViewText(row.name, pet.name)

      val walking = activeWalk != null && activeWalk.petId == pet.id
      views.setViewVisibility(row.status, if (walking) View.VISIBLE else View.GONE)
      views.setViewVisibility(row.pause, if (walking) View.VISIBLE else View.GONE)

      if (walking && activeWalk != null) {
        bindActiveWalk(context, views, row, pet, activeWalk)
        return@forEachIndexed
      }

      views.setViewVisibility(row.reminder, View.VISIBLE)
      views.setOnClickPendingIntent(row.reminder, actionIntent(context, "new_reminder", pet.id))

      // The walk shortcut only makes sense for dogs.
      if (pet.isDog) {
        views.setViewVisibility(row.walk, View.VISIBLE)
        views.setOnClickPendingIntent(row.walk, actionIntent(context, "start_walk", pet.id))
      } else {
        views.setViewVisibility(row.walk, View.GONE)
      }
    }

    appWidgetManager.updateAppWidget(widgetId, views)
  }

  /** Walking pet's row: live status pill, pause/resume pill, tap-to-open. */
  private fun bindActiveWalk(
      context: Context,
      views: RemoteViews,
      row: RowIds,
      pet: WidgetPet,
      walk: ActiveWalk,
  ) {
    // Room for the status text: no bell / paw while walking.
    views.setViewVisibility(row.reminder, View.GONE)
    views.setViewVisibility(row.walk, View.GONE)

    val now = System.currentTimeMillis()
    val elapsedMs = walk.activeSeconds * 1000 +
        if (walk.paused) 0L else maxOf(0L, now - walk.updatedAtMs)
    val format = context.getString(
        if (walk.paused) R.string.dog_walks_widget_walk_paused
        else R.string.dog_walks_widget_walk_running,
        walk.distanceLabel,
    )
    // A stopped chronometer (paused) shows the value as of setChronometer time.
    views.setChronometer(row.status, SystemClock.elapsedRealtime() - elapsedMs, format, !walk.paused)

    val openWalk = actionIntent(context, "open_walk", pet.id)
    views.setOnClickPendingIntent(row.slot, openWalk)
    views.setOnClickPendingIntent(row.status, openWalk)
    views.setContentDescription(
        row.status,
        context.getString(R.string.dog_walks_widget_open_walk_cd),
    )

    val command = if (walk.paused) "resume" else "pause"
    views.setImageViewResource(
        row.pauseIcon,
        if (walk.paused) R.drawable.dog_walks_widget_ic_play else R.drawable.dog_walks_widget_ic_pause,
    )
    views.setContentDescription(
        row.pause,
        context.getString(
            if (walk.paused) R.string.dog_walks_widget_resume_cd else R.string.dog_walks_widget_pause_cd
        ),
    )
    views.setOnClickPendingIntent(
        row.pause,
        if (WalkWidgetBridge.isAvailable) {
          controlBroadcast(context, command, pet.id)
        } else {
          actionIntent(context, "${command}_walk", pet.id)
        },
    )
  }

  private fun openAppIntent(context: Context): PendingIntent {
    val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        ?: Intent(context, MainActivity::class.java)
    return PendingIntent.getActivity(
        context,
        0,
        intent,
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
  }

  private fun parseActiveWalk(json: String?): ActiveWalk? {
    if (json.isNullOrEmpty()) return null
    return try {
      val entry = org.json.JSONObject(json)
      val petId = entry.optString("petId")
      if (petId.isEmpty()) return null
      ActiveWalk(
          petId = petId,
          paused = entry.optBoolean("paused", false),
          distanceLabel = entry.optString("distanceLabel", "0,0 km"),
          activeSeconds = entry.optLong("activeSeconds", 0L),
          updatedAtMs = entry.optLong("updatedAtMs", System.currentTimeMillis()),
      )
    } catch (_: Exception) {
      null
    }
  }

  /** Mirrors the shape walk_home_widget.dart's `syncPetsToHomeWidget` writes. */
  private fun parsePets(json: String?): List<WidgetPet> {
    if (json.isNullOrEmpty()) return emptyList()

    return try {
      val array = JSONArray(json)
      (0 until array.length()).mapNotNull { i ->
        val entry = array.optJSONObject(i) ?: return@mapNotNull null
        val id = entry.optString("id")
        if (id.isEmpty()) return@mapNotNull null
        val name = entry.optString("name", "")
        val emoji = entry.optString("emoji", "").ifEmpty {
          name.take(1).uppercase().ifEmpty { "🐾" }
        }
        val isDog = if (entry.has("isDog")) {
          entry.optBoolean("isDog", false)
        } else {
          entry.optString("species", "").trim().equals("cane", ignoreCase = true)
        }
        // Full-opacity ARGB int (Color.toARGB32 on the Dart side).
        val color = if (entry.has("color")) {
          val argb = entry.optLong("color").toInt()
          Color.rgb(Color.red(argb), Color.green(argb), Color.blue(argb))
        } else {
          DEFAULT_COLOR
        }
        WidgetPet(id = id, name = name, emoji = emoji, isDog = isDog, color = color)
      }
    } catch (_: Exception) {
      emptyList()
    }
  }
}
