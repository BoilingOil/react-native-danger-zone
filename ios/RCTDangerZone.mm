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
    CGRect bounds = rootView.bounds;
    UIEdgeInsets safeArea = rootView.safeAreaInsets;

    // Get both orientations
    UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
    UIInterfaceOrientation interfaceOrientation = UIInterfaceOrientationPortrait;
    if (@available(iOS 13.0, *)) {
      UIWindowScene *windowScene = window.windowScene;
      if (windowScene) {
        interfaceOrientation = windowScene.interfaceOrientation;
      }
    }

    BOOL viewIsLandscape = bounds.size.width > bounds.size.height;

    CGFloat top = 0;
    CGFloat bottom = 0;
    CGFloat left = 0;
    CGFloat right = 0;

    // Get actual values from iOS
    CGFloat notchValue = MAX(MAX(safeArea.top, safeArea.left), safeArea.right);
    CGFloat homeBar = safeArea.bottom > kHomeBarThreshold ? safeArea.bottom : 0;
    if (notchValue < kNotchThreshold) notchValue = 0;

    if (viewIsLandscape) {
      // For landscape, INTERFACE orientation is most reliable for left vs right
      if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
        // Home button on left = notch on RIGHT
        right = notchValue;
      } else {
        // LandscapeRight or fallback: home button on right = notch on LEFT
        left = notchValue;
      }
      bottom = homeBar;
    } else {
      // For portrait, DEVICE orientation tells us upside-down
      if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown) {
        top = homeBar;
        bottom = notchValue;
      } else {
        top = notchValue;
        bottom = homeBar;
      }
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
