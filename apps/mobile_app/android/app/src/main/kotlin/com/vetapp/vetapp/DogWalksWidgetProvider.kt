package com.vetapp.vetapp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * VetApp home-screen widget (owner request 2026-09-29, restyled same day):
 * one row per pet (up to [SLOT_IDS.size]) with the pet's avatar and name, a
 * "Nuovo promemoria" pill and - dogs only - a "Passeggiata" pill.
 *
 * Both pills deep-link into the app through home_widget's launch intent
 * (`homewidget://<action>?petId=...`), handled in walk_home_widget.dart:
 *  - `start_walk`   -> opens a new walk for the pet (active_walk_page.dart)
 *  - `new_reminder` -> opens the reminder creation form for the pet
 * walk_home_widget.dart also keeps [KEY_PETS] / [KEY_TOTAL] fresh via
 * `HomeWidget.saveWidgetData`.
 */
class DogWalksWidgetProvider : HomeWidgetProvider() {

  private data class WidgetPet(
      val id: String,
      val name: String,
      val emoji: String,
      val isDog: Boolean,
      val color: Int,
  )

  companion object {
    private const val KEY_PETS = "dog_walks_widget_pets"
    private const val KEY_TOTAL = "dog_walks_widget_total"

    // AppColors.primary, used when the pet has no identity colour yet.
    private const val DEFAULT_COLOR = 0xFF2E686A.toInt()

    private val SLOT_IDS = intArrayOf(
        R.id.dog_walks_widget_slot_0,
        R.id.dog_walks_widget_slot_1,
        R.id.dog_walks_widget_slot_2,
        R.id.dog_walks_widget_slot_3,
    )
    private val AVATAR_IDS = intArrayOf(
        R.id.dog_walks_widget_avatar_0,
        R.id.dog_walks_widget_avatar_1,
        R.id.dog_walks_widget_avatar_2,
        R.id.dog_walks_widget_avatar_3,
    )
    private val EMOJI_IDS = intArrayOf(
        R.id.dog_walks_widget_emoji_0,
        R.id.dog_walks_widget_emoji_1,
        R.id.dog_walks_widget_emoji_2,
        R.id.dog_walks_widget_emoji_3,
    )
    private val NAME_IDS = intArrayOf(
        R.id.dog_walks_widget_name_0,
        R.id.dog_walks_widget_name_1,
        R.id.dog_walks_widget_name_2,
        R.id.dog_walks_widget_name_3,
    )
    private val REMINDER_IDS = intArrayOf(
        R.id.dog_walks_widget_reminder_0,
        R.id.dog_walks_widget_reminder_1,
        R.id.dog_walks_widget_reminder_2,
        R.id.dog_walks_widget_reminder_3,
    )
    private val WALK_IDS = intArrayOf(
        R.id.dog_walks_widget_walk_0,
        R.id.dog_walks_widget_walk_1,
        R.id.dog_walks_widget_walk_2,
        R.id.dog_walks_widget_walk_3,
    )
  }

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val pets = parsePets(widgetData.getString(KEY_PETS, null)).take(SLOT_IDS.size)
    val total = maxOf(
        pets.size,
        widgetData.getString(KEY_TOTAL, null)?.toIntOrNull() ?: 0,
    )
    val hidden = total - pets.size
    val openApp = openAppIntent(context)

    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.dog_walks_widget)

      // Tapping anywhere that isn't a button (background, header, empty
      // state, a row's name/avatar) just opens the app.
      views.setOnClickPendingIntent(R.id.dog_walks_widget_root, openApp)

      views.setViewVisibility(
          R.id.dog_walks_widget_empty,
          if (pets.isEmpty()) View.VISIBLE else View.GONE,
      )
      if (hidden > 0) {
        views.setTextViewText(
            R.id.dog_walks_widget_more,
            context.getString(R.string.dog_walks_widget_more, hidden),
        )
        views.setViewVisibility(R.id.dog_walks_widget_more, View.VISIBLE)
      } else {
        views.setViewVisibility(R.id.dog_walks_widget_more, View.GONE)
      }

      SLOT_IDS.forEachIndexed { index, slotId ->
        val pet = pets.getOrNull(index)
        if (pet == null) {
          views.setViewVisibility(slotId, View.GONE)
          return@forEachIndexed
        }

        views.setViewVisibility(slotId, View.VISIBLE)
        views.setInt(AVATAR_IDS[index], "setColorFilter", pet.color)
        views.setTextViewText(EMOJI_IDS[index], pet.emoji)
        views.setTextViewText(NAME_IDS[index], pet.name)

        views.setOnClickPendingIntent(
            REMINDER_IDS[index],
            actionIntent(context, "new_reminder", pet.id),
        )

        // The walk shortcut only makes sense for dogs.
        if (pet.isDog) {
          views.setViewVisibility(WALK_IDS[index], View.VISIBLE)
          views.setOnClickPendingIntent(
              WALK_IDS[index],
              actionIntent(context, "start_walk", pet.id),
          )
        } else {
          views.setViewVisibility(WALK_IDS[index], View.GONE)
        }
      }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  private fun actionIntent(context: Context, action: String, petId: String): PendingIntent =
      HomeWidgetLaunchIntent.getActivity(
          context,
          MainActivity::class.java,
          Uri.parse("homewidget://$action?petId=${Uri.encode(petId)}"),
      )

  private fun openAppIntent(context: Context): PendingIntent {
    val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        ?: android.content.Intent(context, MainActivity::class.java)
    return PendingIntent.getActivity(
        context,
        0,
        intent,
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
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
