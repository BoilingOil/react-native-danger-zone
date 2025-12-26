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
    CGRect bounds = rootView.bounds;
    UIEdgeInsets safeArea = rootView.safeAreaInsets;

    BOOL viewIsLandscape = bounds.size.width > bounds.size.height;

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
        // FaceUp, FaceDown, Unknown - use cached value BUT
        // if cached is landscape and view is portrait, the cache is stale
        // (we transitioned through landscape to portrait/upside-down while flat)
        if (!viewIsLandscape &&
            (self->_lastKnownOrientation == UIDeviceOrientationLandscapeLeft ||
             self->_lastKnownOrientation == UIDeviceOrientationLandscapeRight)) {
          // When flat during landscape->portrait transition, we can't tell if
          // it's normal portrait or upside-down. Default to portrait; the 50ms
          // polling will catch the correct orientation once device tilts enough.
          deviceOrientation = UIDeviceOrientationPortrait;
          self->_lastKnownOrientation = UIDeviceOrientationPortrait;
        } else {
          deviceOrientation = self->_lastKnownOrientation;
        }
        break;
    }

    CGFloat top = 0;
    CGFloat bottom = 0;
    CGFloat left = 0;
    CGFloat right = 0;

    // For upside down: iOS keeps view in portrait, so use portrait safe area values
    // and swap top/bottom ourselves
    if (deviceOrientation == UIDeviceOrientationPortraitUpsideDown && !viewIsLandscape) {
      // Device is upside down and view is portrait - swap top and bottom
      CGFloat notchValue = safeArea.top > kNotchThreshold ? safeArea.top : 0;
      CGFloat homeBar = safeArea.bottom > kHomeBarThreshold ? safeArea.bottom : 0;
      top = homeBar;      // Home bar now at top
      bottom = notchValue; // Notch now at bottom
    }
    else if (viewIsLandscape) {
      // Landscape - notch on left or right
      CGFloat notchValue = MAX(safeArea.left, safeArea.right);
      if (notchValue < kNotchThreshold) notchValue = 0;
      CGFloat homeBar = safeArea.bottom > kHomeBarThreshold ? safeArea.bottom : 0;

      if (deviceOrientation == UIDeviceOrientationLandscapeLeft) {
        left = notchValue;
      } else if (deviceOrientation == UIDeviceOrientationLandscapeRight) {
        right = notchValue;
      } else {
        // Device says portrait but view is landscape - use safe area to determine
        if (safeArea.left > safeArea.right) {
          left = notchValue;
        } else {
          right = notchValue;
        }
      }
      bottom = homeBar;
    }
    else {
      // Portrait (normal)
      CGFloat notchValue = safeArea.top > kNotchThreshold ? safeArea.top : 0;
      CGFloat homeBar = safeArea.bottom > kHomeBarThreshold ? safeArea.bottom : 0;
      top = notchValue;
      bottom = homeBar;
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
