package com.dangerzone

import android.os.Build
import android.view.WindowInsets
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableNativeMap
import com.facebook.react.module.annotations.ReactModule

@ReactModule(name = DangerZoneModule.NAME)
class DangerZoneModule(reactContext: ReactApplicationContext) :
    NativeDangerZoneSpec(reactContext) {

  companion object {
    const val NAME = "NativeDangerZone"
  }

  override fun getName(): String = NAME

  override fun getInsets(): WritableNativeMap {
    val result = WritableNativeMap()
    result.putDouble("top", 0.0)
    result.putDouble("bottom", 0.0)
    result.putDouble("left", 0.0)
    result.putDouble("right", 0.0)

    try {
      val activity = currentActivity ?: return result
      val decorView = activity.window?.decorView ?: return result
      val density = activity.resources.displayMetrics.density

      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        val windowInsets = decorView.rootWindowInsets ?: return result
        val insets = windowInsets.getInsets(
          WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()
        )
        result.putDouble("top", (insets.top / density).toDouble())
        result.putDouble("bottom", (insets.bottom / density).toDouble())
        result.putDouble("left", (insets.left / density).toDouble())
        result.putDouble("right", (insets.right / density).toDouble())
      } else {
        @Suppress("DEPRECATION")
        val windowInsets = decorView.rootWindowInsets ?: return result
        @Suppress("DEPRECATION")
        result.putDouble("top", (windowInsets.systemWindowInsetTop / density).toDouble())
        @Suppress("DEPRECATION")
        result.putDouble("bottom", (windowInsets.systemWindowInsetBottom / density).toDouble())
        @Suppress("DEPRECATION")
        result.putDouble("left", (windowInsets.systemWindowInsetLeft / density).toDouble())
        @Suppress("DEPRECATION")
        result.putDouble("right", (windowInsets.systemWindowInsetRight / density).toDouble())
      }
    } catch (e: Exception) {
      // Return zeros on error
    }

    return result
  }
}
