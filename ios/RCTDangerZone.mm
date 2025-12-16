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

    // Force layout to complete
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [rootView setNeedsLayout];
    [rootView layoutIfNeeded];
    [CATransaction commit];
    [CATransaction flush];

    CGRect bounds = rootView.bounds;
    UIEdgeInsets safeArea = rootView.safeAreaInsets;

    UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
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
      // In landscape, use the ACTUAL safe area values to determine notch side
      // The side with the larger raw inset has the notch
      // (Even if they report equal after threshold, the raw values differ slightly)
      if (safeArea.left > safeArea.right) {
        left = notchValue;
      } else if (safeArea.right > safeArea.left) {
        right = notchValue;
      } else {
        // Truly equal - use device orientation as tiebreaker
        if (deviceOrientation == UIDeviceOrientationLandscapeLeft) {
          left = notchValue;
        } else if (deviceOrientation == UIDeviceOrientationLandscapeRight) {
          right = notchValue;
        } else {
          // Last resort - use interface orientation
          UIInterfaceOrientation interfaceOrientation = UIInterfaceOrientationPortrait;
          if (@available(iOS 13.0, *)) {
            UIWindowScene *windowScene = window.windowScene;
            if (windowScene) {
              interfaceOrientation = windowScene.interfaceOrientation;
            }
          }
          if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
            right = notchValue;
          } else {
            left = notchValue;
          }
        }
      }
      bottom = homeBar;
    } else {
      // Portrait
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
