package com.vetapp.vetapp

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * "Passeggiate" home-screen widget (owner request, 2026-09-29): shows up to
 * [SLOT_IDS.size] of the owner's pets, tapping one opens the app straight
 * into a new walk for that pet (see active_walk_page.dart's `autoStart` and
 * walk_home_widget.dart, which is what actually keeps [KEY_PETS] fresh via
 * `HomeWidget.saveWidgetData`).
 */
class DogWalksWidgetProvider : HomeWidgetProvider() {

  private data class WidgetPet(val id: String, val name: String, val emoji: String)

  companion object {
    private const val KEY_PETS = "dog_walks_widget_pets"

    private val SLOT_IDS = intArrayOf(
        R.id.dog_walks_widget_slot_0,
        R.id.dog_walks_widget_slot_1,
        R.id.dog_walks_widget_slot_2,
        R.id.dog_walks_widget_slot_3,
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
  }

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val pets = parsePets(widgetData.getString(KEY_PETS, null))

    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.dog_walks_widget)
      views.setViewVisibility(
          R.id.dog_walks_widget_empty,
          if (pets.isEmpty()) View.VISIBLE else View.GONE,
      )

      SLOT_IDS.forEachIndexed { index, slotId ->
        val pet = pets.getOrNull(index)
        if (pet == null) {
          views.setViewVisibility(slotId, View.GONE)
          return@forEachIndexed
        }

        views.setViewVisibility(slotId, View.VISIBLE)
        views.setTextViewText(EMOJI_IDS[index], pet.emoji)
        views.setTextViewText(NAME_IDS[index], pet.name)

        val pendingIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("homewidget://start_walk?petId=${Uri.encode(pet.id)}"),
        )
        views.setOnClickPendingIntent(slotId, pendingIntent)
      }

      appWidgetManager.updateAppWidget(widgetId, views)
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
        WidgetPet(
            id = id,
            name = entry.optString("name", ""),
            emoji = entry.optString("emoji", "🐾"),
        )
      }
    } catch (_: Exception) {
      emptyList()
    }
  }
}
