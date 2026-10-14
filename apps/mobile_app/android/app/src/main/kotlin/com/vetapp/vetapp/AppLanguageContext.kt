package com.vetapp.vetapp

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/** Native notification/widget copy follows the persisted Flutter app choice. */
internal object AppLanguageContext {
  fun localized(base: Context): Context {
    val variant = base.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        .getString("flutter.vet_app.language_variant", null)
    val deviceCode = base.resources.configuration.locales[0].language
    val code = (variant ?: deviceCode).substringBefore("-")
        .takeIf { it in setOf("it", "en", "es", "fr") } ?: "it"
    val configuration = Configuration(base.resources.configuration)
    configuration.setLocale(Locale.forLanguageTag(code))
    return base.createConfigurationContext(configuration)
  }
}
