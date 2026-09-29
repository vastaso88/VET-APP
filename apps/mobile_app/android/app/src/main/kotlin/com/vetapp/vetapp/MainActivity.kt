package com.vetapp.vetapp

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    WalkWidgetBridge.attach(null)
    super.cleanUpFlutterEngine(flutterEngine)
  }

  override fun onDestroy() {
    val finishing = isFinishing
    super.onDestroy()
    // The engine (and the walk tracking in it) dies with a finished activity:
    // stop advertising the walk on the widget. A walk recovered on the next
    // launch is re-published by Dart.
    if (finishing) DogWalksWidgetProvider.clearActiveWalk(applicationContext)
  }
}
