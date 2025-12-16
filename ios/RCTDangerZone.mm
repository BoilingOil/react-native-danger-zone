#import "RCTDangerZone.h"
#import <UIKit/UIKit.h>

// Notch is ~44-59pt, home bar is ~21-34pt
// Anything below this is corner rounding garbage we don't care about
static const CGFloat kNotchThreshold = 40.0;
static const CGFloat kHomeBarThreshold = 15.0;

@implementation RCTDangerZone {
  UIDeviceOrientation _lastKnownOrientation;
}

RCT_EXPORT_MODULE(NativeDangerZone)

- (instancetype)init {
  self = [super init];
  if (self) {
    // THIS IS CRITICAL - without it, UIDevice.currentDevice.orientation doesn't update!
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    _lastKnownOrientation = UIDeviceOrientationPortrait;
  }
  return self;
}

- (void)dealloc {
  [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

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

    // Get device orientation - use cached value if flat/unknown
    UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
    switch (deviceOrientation) {
      case UIDeviceOrientationPortrait:
      case UIDeviceOrientationPortraitUpsideDown:
      case UIDeviceOrientationLandscapeLeft:
      case UIDeviceOrientationLandscapeRight:
        // Valid orientation - cache it
        self->_lastKnownOrientation = deviceOrientation;
        break;
      default:
        // FaceUp, FaceDown, Unknown - use cached value
        deviceOrientation = self->_lastKnownOrientation;
        break;
    }

    CGFloat top = 0;
    CGFloat bottom = 0;
    CGFloat left = 0;
    CGFloat right = 0;

    // Get the notch value from whichever edge has it
    CGFloat notchValue = MAX(MAX(safeArea.top, safeArea.left), safeArea.right);
    CGFloat homeBar = safeArea.bottom > kHomeBarThreshold ? safeArea.bottom : 0;
    if (notchValue < kNotchThreshold) notchValue = 0;

    // Use device orientation to determine where the notch physically is
    switch (deviceOrientation) {
      case UIDeviceOrientationLandscapeLeft:
        // Device rotated left = notch on LEFT
        left = notchValue;
        bottom = homeBar;
        break;
      case UIDeviceOrientationLandscapeRight:
        // Device rotated right = notch on RIGHT
        right = notchValue;
        bottom = homeBar;
        break;
      case UIDeviceOrientationPortraitUpsideDown:
        // Upside down = notch at BOTTOM
        top = homeBar;
        bottom = notchValue;
        break;
      default:
        // Portrait = notch at TOP
        top = notchValue;
        bottom = homeBar;
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
