package com.dangerzone

import android.os.Build
import android.view.DisplayCutout
import android.view.WindowInsets
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableNativeMap
import com.facebook.react.module.annotations.ReactModule

@ReactModule(name = DangerZoneModule.NAME)
class DangerZoneModule(reactContext: ReactApplicationContext) :
    NativeDangerZoneSpec(reactContext) {

  companion object {
    const val NAME = "NativeDangerZone"
    // Thresholds in dp - only care about actual notch/nav bar, not rounded corners
    const val NOTCH_THRESHOLD = 24.0
    const val NAV_BAR_THRESHOLD = 20.0
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

        // Get display cutout (notch/punch hole) insets
        val cutoutInsets = windowInsets.getInsets(WindowInsets.Type.displayCutout())

        // Get navigation bar insets (home bar area)
        val navBarInsets = windowInsets.getInsets(WindowInsets.Type.navigationBars())

        // Convert to dp
        val topDp = cutoutInsets.top / density
        val bottomDp = navBarInsets.bottom / density
        val leftDp = cutoutInsets.left / density
        val rightDp = cutoutInsets.right / density

        // Apply thresholds - only keep significant insets
        result.putDouble("top", if (topDp > NOTCH_THRESHOLD) topDp.toDouble() else 0.0)
        result.putDouble("bottom", if (bottomDp > NAV_BAR_THRESHOLD) bottomDp.toDouble() else 0.0)
        result.putDouble("left", if (leftDp > NOTCH_THRESHOLD) leftDp.toDouble() else 0.0)
        result.putDouble("right", if (rightDp > NOTCH_THRESHOLD) rightDp.toDouble() else 0.0)

      } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        // API 28-29: Use DisplayCutout API
        val windowInsets = decorView.rootWindowInsets ?: return result
        val cutout = windowInsets.displayCutout

        @Suppress("DEPRECATION")
        val navBottom = windowInsets.systemWindowInsetBottom / density

        if (cutout != null) {
          val topDp = cutout.safeInsetTop / density
          val leftDp = cutout.safeInsetLeft / density
          val rightDp = cutout.safeInsetRight / density

          result.putDouble("top", if (topDp > NOTCH_THRESHOLD) topDp.toDouble() else 0.0)
          result.putDouble("left", if (leftDp > NOTCH_THRESHOLD) leftDp.toDouble() else 0.0)
          result.putDouble("right", if (rightDp > NOTCH_THRESHOLD) rightDp.toDouble() else 0.0)
        }

        result.putDouble("bottom", if (navBottom > NAV_BAR_THRESHOLD) navBottom.toDouble() else 0.0)

      } else {
        // API < 28: No notch support, just nav bar
        @Suppress("DEPRECATION")
        val windowInsets = decorView.rootWindowInsets ?: return result
        @Suppress("DEPRECATION")
        val bottomDp = windowInsets.systemWindowInsetBottom / density

        result.putDouble("bottom", if (bottomDp > NAV_BAR_THRESHOLD) bottomDp.toDouble() else 0.0)
      }
    } catch (e: Exception) {
      // Return zeros on error
    }

    return result
  }
}
