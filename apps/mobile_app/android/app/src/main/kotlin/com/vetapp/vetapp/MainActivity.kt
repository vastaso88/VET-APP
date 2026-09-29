package com.vetapp.vetapp

import android.content.Intent
import android.os.Bundle
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
}
