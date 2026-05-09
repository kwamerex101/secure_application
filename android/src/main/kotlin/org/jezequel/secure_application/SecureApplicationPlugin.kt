package org.jezequel.secure_application

import android.app.Activity
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.view.WindowManager.LayoutParams
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.OnLifecycleEvent
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter

/** SecureApplicationPlugin */
class SecureApplicationPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, LifecycleObserver {
  private var activity: Activity? = null
  private var channel: MethodChannel? = null
  private var lifecycle: Lifecycle? = null
  private var secured: Boolean = false

  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "secure_application")
    channel?.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel?.setMethodCallHandler(null)
    channel = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)
    lifecycle?.addObserver(this)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivity() {
    lifecycle?.removeObserver(this)
    lifecycle = null
    activity = null
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  @OnLifecycleEvent(Lifecycle.Event.ON_PAUSE)
  fun onAppPause() {
    if (secured) {
      channel?.invokeMethod("lock", null)
    }
  }

  @OnLifecycleEvent(Lifecycle.Event.ON_RESUME)
  fun onAppResume() {
    if (secured) {
      channel?.invokeMethod("unlock", null)
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "secure" -> {
        secured = true
        activity?.window?.addFlags(LayoutParams.FLAG_SECURE)
        result.success(true)
      }
      "open" -> {
        secured = false
        activity?.window?.clearFlags(LayoutParams.FLAG_SECURE)
        result.success(true)
      }
      "lock", "unlock", "opacity" -> {
        // No-op on Android; visual gate is handled in Dart, FLAG_SECURE handles app switcher.
        result.success(true)
      }
      else -> result.notImplemented()
    }
  }
}
