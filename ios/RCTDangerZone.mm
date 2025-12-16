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

    // Get the interface orientation from window scene
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (@available(iOS 13.0, *)) {
      UIWindowScene *windowScene = window.windowScene;
      if (windowScene) {
        orientation = windowScene.interfaceOrientation;
      }
    }

    // Double-check: if bounds say landscape but orientation says portrait, trust bounds
    BOOL boundsLandscape = bounds.size.width > bounds.size.height;
    BOOL orientationLandscape = UIInterfaceOrientationIsLandscape(orientation);

    CGFloat top = 0;
    CGFloat bottom = 0;
    CGFloat left = 0;
    CGFloat right = 0;

    // Get the notch value (max of top/left/right that's above threshold)
    CGFloat notchValue = 0;
    if (safeArea.top > kNotchThreshold) notchValue = safeArea.top;
    if (safeArea.left > kNotchThreshold) notchValue = MAX(notchValue, safeArea.left);
    if (safeArea.right > kNotchThreshold) notchValue = MAX(notchValue, safeArea.right);

    // Get home bar value
    CGFloat homeBar = safeArea.bottom > kHomeBarThreshold ? safeArea.bottom : 0;

    if (boundsLandscape) {
      // We're in landscape - figure out which side has the notch
      if (orientationLandscape) {
        // Orientation matches bounds, trust it
        if (orientation == UIInterfaceOrientationLandscapeLeft) {
          right = notchValue;
          left = 0;
        } else {
          left = notchValue;
          right = 0;
        }
      } else {
        // Orientation is stale/wrong - use safe area values to determine
        // The side with the larger inset has the notch
        if (safeArea.left >= safeArea.right) {
          left = notchValue;
          right = 0;
        } else {
          right = notchValue;
          left = 0;
        }
      }
      top = 0;
      bottom = homeBar;
    } else {
      // Portrait
      top = notchValue;
      bottom = homeBar;
      left = 0;
      right = 0;
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
