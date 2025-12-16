#import "RCTDangerZone.h"
#import <UIKit/UIKit.h>

// Only report insets above this threshold (filters out corner rounding)
// Notch is ~44-59pt, home bar is ~34pt, corner rounding is ~0-20pt
static const CGFloat kInsetThreshold = 24.0;

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

    if (window) {
      [window layoutIfNeeded];
      UIEdgeInsets safeArea = window.safeAreaInsets;

      // Only report significant insets (notch, home bar) - ignore corner rounding
      CGFloat top = safeArea.top >= kInsetThreshold ? safeArea.top : 0;
      CGFloat bottom = safeArea.bottom >= kInsetThreshold ? safeArea.bottom : 0;
      CGFloat left = safeArea.left >= kInsetThreshold ? safeArea.left : 0;
      CGFloat right = safeArea.right >= kInsetThreshold ? safeArea.right : 0;

      result = @{
        @"top": @(top),
        @"bottom": @(bottom),
        @"left": @(left),
        @"right": @(right)
      };
    }
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
