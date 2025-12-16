#import "RCTDangerZone.h"
#import <UIKit/UIKit.h>

// Notch is ~44-59pt, home bar is ~21-34pt
// Anything below this is corner rounding garbage we don't care about
static const CGFloat kNotchThreshold = 40.0;
static const CGFloat kHomeBarThreshold = 15.0;

@implementation RCTDangerZone

RCT_EXPORT_MODULE(NativeDangerZone)

- (NSDictionary *)getInsets {
  __block NSDictionary *result = @{
    @"top": @0,
    @"bottom": @0,
    @"left": @0,
    @"right": @0
  };

  void (^fetchInsets)(void) = ^{
    UIWindow *window = [self getKeyWindow];
    if (!window) return;

    UIViewController *rootVC = window.rootViewController;
    if (!rootVC) return;

    UIView *rootView = rootVC.view;
    UIEdgeInsets safeArea = rootView.safeAreaInsets;

    // Use DEVICE orientation - this is the physical position of the device
    // iOS can't hide this from us even if it refuses to rotate the interface
    UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;

    CGFloat top = 0;
    CGFloat bottom = 0;
    CGFloat left = 0;
    CGFloat right = 0;

    // Get the notch value (max of any edge that's above threshold)
    CGFloat notchValue = 0;
    if (safeArea.top > kNotchThreshold) notchValue = safeArea.top;
    if (safeArea.left > kNotchThreshold) notchValue = MAX(notchValue, safeArea.left);
    if (safeArea.right > kNotchThreshold) notchValue = MAX(notchValue, safeArea.right);

    // If we still don't have a notch value, device might be in portrait with Dynamic Island
    // Use a reasonable default
    if (notchValue == 0) notchValue = 59.0;

    // Get home bar value
    CGFloat homeBar = safeArea.bottom > kHomeBarThreshold ? safeArea.bottom : 0;
    if (homeBar == 0) homeBar = 34.0; // Default home bar for Face ID devices

    // Device orientation tells us exactly where the notch physically is
    // Note: Device orientation is from the device's perspective, not the UI's
    switch (deviceOrientation) {
      case UIDeviceOrientationLandscapeLeft:
        // Device rotated left = notch is on LEFT side of screen
        left = notchValue;
        right = 0;
        top = 0;
        bottom = homeBar;
        break;
      case UIDeviceOrientationLandscapeRight:
        // Device rotated right = notch is on RIGHT side of screen
        right = notchValue;
        left = 0;
        top = 0;
        bottom = homeBar;
        break;
      case UIDeviceOrientationPortraitUpsideDown:
        // Upside down = notch at BOTTOM (even though iOS won't rotate to this)
        top = homeBar;
        bottom = notchValue;
        left = 0;
        right = 0;
        break;
      case UIDeviceOrientationFaceUp:
      case UIDeviceOrientationFaceDown:
      case UIDeviceOrientationUnknown:
        // Device flat or unknown - fall back to interface orientation
        {
          UIInterfaceOrientation interfaceOrientation = UIInterfaceOrientationPortrait;
          if (@available(iOS 13.0, *)) {
            UIWindowScene *windowScene = window.windowScene;
            if (windowScene) {
              interfaceOrientation = windowScene.interfaceOrientation;
            }
          }
          if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
            right = notchValue;
            left = 0;
            top = 0;
            bottom = homeBar;
          } else if (interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
            left = notchValue;
            right = 0;
            top = 0;
            bottom = homeBar;
          } else {
            top = notchValue;
            bottom = homeBar;
            left = 0;
            right = 0;
          }
        }
        break;
      default: // Portrait
        top = notchValue;
        bottom = homeBar;
        left = 0;
        right = 0;
        break;
    }

    result = @{
      @"top": @(top),
      @"bottom": @(bottom),
      @"left": @(left),
      @"right": @(right)
    };
  };

  if ([NSThread isMainThread]) {
    fetchInsets();
  } else {
    dispatch_sync(dispatch_get_main_queue(), fetchInsets);
  }

  return result;
}

- (UIWindow *)getKeyWindow {
  if (@available(iOS 15.0, *)) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
      if ([scene isKindOfClass:[UIWindowScene class]]) {
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
          if (window.isKeyWindow) {
            return window;
          }
        }
      }
    }
  } else {
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
      if (window.isKeyWindow) {
        return window;
      }
    }
  }
  return nil;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeDangerZoneSpecJSI>(params);
}

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

@end
