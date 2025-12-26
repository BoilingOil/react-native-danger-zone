#import "RCTDangerZone.h"
#import <UIKit/UIKit.h>

// Notch is ~44-59pt, home bar is ~21-34pt
static const CGFloat kNotchThreshold = 40.0;
static const CGFloat kHomeBarThreshold = 15.0;

typedef NS_ENUM(NSInteger, NotchPosition) {
  NotchPositionTop,
  NotchPositionBottom,
  NotchPositionLeft,
  NotchPositionRight
};

@implementation RCTDangerZone {
  CMMotionManager *_motionManager;
  NotchPosition _lastKnownPosition;
}

RCT_EXPORT_MODULE(NativeDangerZone)

- (instancetype)init {
  self = [super init];
  if (self) {
    _motionManager = [[CMMotionManager alloc] init];
    _motionManager.deviceMotionUpdateInterval = 0.1;
    [_motionManager startDeviceMotionUpdates];
    _lastKnownPosition = NotchPositionTop;
  }
  return self;
}

- (void)dealloc {
  [_motionManager stopDeviceMotionUpdates];
}

- (NotchPosition)getNotchPositionFromGravity {
  CMDeviceMotion *motion = _motionManager.deviceMotion;
  if (!motion) {
    return _lastKnownPosition;
  }

  // Gravity vector: points toward Earth
  // x: positive = right side down, negative = left side down
  // y: positive = bottom down (normal portrait), negative = top down (upside down)
  // z: positive = face down, negative = face up
  double x = motion.gravity.x;
  double y = motion.gravity.y;

  // Determine orientation based on which axis has stronger gravity component
  if (fabs(y) > fabs(x)) {
    // More portrait than landscape
    if (y > 0) {
      _lastKnownPosition = NotchPositionTop;      // Normal portrait
    } else {
      _lastKnownPosition = NotchPositionBottom;   // Upside down
    }
  } else {
    // More landscape than portrait
    if (x > 0) {
      _lastKnownPosition = NotchPositionLeft;     // Landscape right (notch on left)
    } else {
      _lastKnownPosition = NotchPositionRight;    // Landscape left (notch on right)
    }
  }

  return _lastKnownPosition;
}

- (NSDictionary *)getInsets {
  __block NSDictionary *result = @{
    @"top": @0,
    @"bottom": @0,
    @"left": @0,
    @"right": @0
  };

  // Get notch position from accelerometer (works even when flat)
  NotchPosition notchPosition = [self getNotchPositionFromGravity];

  void (^fetchInsets)(void) = ^{
    UIWindow *window = [self getKeyWindow];
    if (!window) return;

    UIViewController *rootVC = window.rootViewController;
    if (!rootVC) return;

    UIView *rootView = rootVC.view;
    UIEdgeInsets safeArea = rootView.safeAreaInsets;

    // Get the notch value (the larger of top/left/right safe areas)
    CGFloat notchValue = MAX(safeArea.top, MAX(safeArea.left, safeArea.right));
    if (notchValue < kNotchThreshold) notchValue = 0;

    // Get home bar value
    CGFloat homeBar = safeArea.bottom > kHomeBarThreshold ? safeArea.bottom : 0;

    CGFloat top = 0, bottom = 0, left = 0, right = 0;

    switch (notchPosition) {
      case NotchPositionTop:
        top = notchValue;
        bottom = homeBar;
        break;
      case NotchPositionBottom:
        bottom = notchValue;
        top = homeBar;
        break;
      case NotchPositionLeft:
        left = notchValue;
        bottom = homeBar;
        break;
      case NotchPositionRight:
        right = notchValue;
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
