#import "RCTDangerZone.h"
#import <UIKit/UIKit.h>

// Notch is ~44-59pt, home bar is ~21-34pt
static const CGFloat kNotchThreshold = 40.0;
static const CGFloat kHomeBarThreshold = 15.0;

// Hysteresis threshold - must exceed this to change orientation
// Prevents jitter at 45° boundaries
static const double kOrientationThreshold = 0.2;

typedef NS_ENUM(NSInteger, NotchPosition) {
  NotchPositionTop,
  NotchPositionBottom,
  NotchPositionLeft,
  NotchPositionRight
};

@implementation RCTDangerZone {
  CMMotionManager *_motionManager;
  NotchPosition _lastKnownPosition;
  BOOL _hasMotionData;
}

RCT_EXPORT_MODULE(NativeDangerZone)

- (instancetype)init {
  self = [super init];
  if (self) {
    _motionManager = [[CMMotionManager alloc] init];
    _lastKnownPosition = NotchPositionTop;
    _hasMotionData = NO;

    if (_motionManager.isDeviceMotionAvailable) {
      _motionManager.deviceMotionUpdateInterval = 0.05; // 50ms for responsive updates
      [_motionManager startDeviceMotionUpdates];
    }

    // Also enable UIDevice orientation for fallback
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
  }
  return self;
}

- (void)dealloc {
  [_motionManager stopDeviceMotionUpdates];
  [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

- (NotchPosition)getNotchPositionFromMotion {
  CMDeviceMotion *motion = _motionManager.deviceMotion;
  if (!motion) {
    return _lastKnownPosition;
  }

  _hasMotionData = YES;

  // Gravity vector points toward Earth
  // x: positive = right side down, negative = left side down
  // y: positive = bottom down (normal portrait), negative = top down (upside down)
  double x = motion.gravity.x;
  double y = motion.gravity.y;

  double absX = fabs(x);
  double absY = fabs(y);

  // Only change orientation if we clearly exceed threshold
  // This prevents jitter at boundaries
  NotchPosition newPosition = _lastKnownPosition;

  if (absY > absX + kOrientationThreshold) {
    // Clearly portrait
    newPosition = (y > 0) ? NotchPositionTop : NotchPositionBottom;
  } else if (absX > absY + kOrientationThreshold) {
    // Clearly landscape
    newPosition = (x > 0) ? NotchPositionLeft : NotchPositionRight;
  }
  // else: in the "dead zone" near 45°, keep previous orientation

  _lastKnownPosition = newPosition;
  return newPosition;
}

- (NotchPosition)getNotchPositionFromUIDevice:(BOOL)viewIsLandscape window:(UIWindow *)window {
  UIDeviceOrientation orientation = UIDevice.currentDevice.orientation;

  switch (orientation) {
    case UIDeviceOrientationPortrait:
      return NotchPositionTop;
    case UIDeviceOrientationPortraitUpsideDown:
      return NotchPositionBottom;
    case UIDeviceOrientationLandscapeLeft:
      // Device rotated left = home button left = notch on right
      return NotchPositionRight;
    case UIDeviceOrientationLandscapeRight:
      // Device rotated right = home button right = notch on left
      return NotchPositionLeft;
    default:
      // FaceUp, FaceDown, Unknown - use interface orientation (works in simulator)
      if (@available(iOS 13.0, *)) {
        UIWindowScene *windowScene = window.windowScene;
        if (windowScene) {
          switch (windowScene.interfaceOrientation) {
            case UIInterfaceOrientationPortrait:
              return NotchPositionTop;
            case UIInterfaceOrientationPortraitUpsideDown:
              return NotchPositionBottom;
            case UIInterfaceOrientationLandscapeLeft:
              // Interface landscape left = notch on left
              return NotchPositionLeft;
            case UIInterfaceOrientationLandscapeRight:
              // Interface landscape right = notch on right
              return NotchPositionRight;
            default:
              break;
          }
        }
      }
      return _lastKnownPosition;
  }
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

    // Try CoreMotion first (works for upside-down on real device)
    // Fall back to UIDevice/interface orientation (works for simulator)
    NotchPosition notchPosition;
    if (self->_hasMotionData || self->_motionManager.deviceMotion != nil) {
      notchPosition = [self getNotchPositionFromMotion];
    } else {
      notchPosition = [self getNotchPositionFromUIDevice:viewIsLandscape window:window];
      self->_lastKnownPosition = notchPosition;
    }

    // Calculate notch value from safe area
    CGFloat notchValue = 0;
    CGFloat homeBar = 0;

    if (viewIsLandscape) {
      // In landscape, notch is on left or right
      notchValue = MAX(safeArea.left, safeArea.right);
      homeBar = safeArea.bottom;
    } else {
      // In portrait, notch is top (or bottom if upside down, but iOS reports same)
      notchValue = safeArea.top;
      homeBar = safeArea.bottom;
    }

    // Apply thresholds
    if (notchValue < kNotchThreshold) notchValue = 0;
    if (homeBar < kHomeBarThreshold) homeBar = 0;

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
