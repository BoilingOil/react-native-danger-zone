#import "RCTDangerZone.h"
#import <UIKit/UIKit.h>

static const CGFloat kNotchThreshold = 40.0;   // Notch is ~44-59pt
static const CGFloat kHomeBarThreshold = 15.0; // Home bar is ~21-34pt
static const double kHysteresis = 0.2;         // Prevents jitter at 45°

typedef NS_ENUM(NSInteger, NotchPosition) {
  NotchPositionTop,
  NotchPositionLeft,
  NotchPositionRight
};

@implementation RCTDangerZone {
  CMMotionManager *_motionManager;
  NotchPosition _lastPosition;
}

RCT_EXPORT_MODULE(NativeDangerZone)

- (instancetype)init {
  self = [super init];
  if (self) {
    _lastPosition = NotchPositionTop;
    _motionManager = [[CMMotionManager alloc] init];
    if (_motionManager.isDeviceMotionAvailable) {
      _motionManager.deviceMotionUpdateInterval = 0.05;
      [_motionManager startDeviceMotionUpdates];
    }
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
  }
  return self;
}

- (void)dealloc {
  [_motionManager stopDeviceMotionUpdates];
  [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

- (NotchPosition)getNotchPosition:(UIWindow *)window {
  // 1. CoreMotion (best - works for all orientations on real device)
  CMDeviceMotion *motion = _motionManager.deviceMotion;
  if (motion) {
    double x = motion.gravity.x;
    double y = motion.gravity.y;
    double absX = fabs(x);
    double absY = fabs(y);

    if (absY > absX + kHysteresis) {
      // Portrait (no upside-down support - Apple won't rotate iPhone apps)
      _lastPosition = NotchPositionTop;
    } else if (absX > absY + kHysteresis) {
      // Landscape: x > 0 = right side down = notch right
      _lastPosition = (x > 0) ? NotchPositionRight : NotchPositionLeft;
    }
    return _lastPosition;
  }

  // 2. UIDevice orientation
  switch (UIDevice.currentDevice.orientation) {
    case UIDeviceOrientationPortrait:
      return NotchPositionTop;
    case UIDeviceOrientationLandscapeLeft:
      return NotchPositionRight;
    case UIDeviceOrientationLandscapeRight:
      return NotchPositionLeft;
    default:
      break;
  }

  // 3. interfaceOrientation (simulator fallback)
  if (@available(iOS 13.0, *)) {
    UIWindowScene *scene = window.windowScene;
    if (scene) {
      switch (scene.interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
          return NotchPositionTop;
        case UIInterfaceOrientationLandscapeLeft:
          return NotchPositionRight;
        case UIInterfaceOrientationLandscapeRight:
          return NotchPositionLeft;
        default:
          break;
      }
    }
  }

  return _lastPosition;
}

- (NSDictionary *)getInsets {
  __block NSDictionary *result = @{@"top": @0, @"bottom": @0, @"left": @0, @"right": @0};

  void (^work)(void) = ^{
    UIWindow *window = nil;
    if (@available(iOS 15.0, *)) {
      for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
          for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w.isKeyWindow) { window = w; break; }
          }
        }
        if (window) break;
      }
    } else {
      for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w.isKeyWindow) { window = w; break; }
      }
    }
    if (!window || !window.rootViewController) return;

    UIEdgeInsets safe = window.rootViewController.view.safeAreaInsets;
    CGRect bounds = window.rootViewController.view.bounds;
    BOOL landscape = bounds.size.width > bounds.size.height;

    CGFloat notch = landscape ? MAX(safe.left, safe.right) : safe.top;
    CGFloat home = safe.bottom;

    if (notch < kNotchThreshold) notch = 0;
    if (home < kHomeBarThreshold) home = 0;

    CGFloat t = 0, b = 0, l = 0, r = 0;
    switch ([self getNotchPosition:window]) {
      case NotchPositionTop:   t = notch; b = home; break;
      case NotchPositionLeft:  l = notch; b = home; break;
      case NotchPositionRight: r = notch; b = home; break;
    }

    result = @{@"top": @(t), @"bottom": @(b), @"left": @(l), @"right": @(r)};
  };

  if ([NSThread isMainThread]) work();
  else dispatch_sync(dispatch_get_main_queue(), work);

  return result;
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeDangerZoneSpecJSI>(params);
}

+ (BOOL)requiresMainQueueSetup { return YES; }

@end
