#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <CoreHaptics/CoreHaptics.h>

@protocol CHHapticPatternPlayer;
static CHHapticEngine *sharedHapticEngine = nil;
static UILabel *g_timeBatteryLabel = nil;
static NSTimer *g_refreshTimer = nil;

#pragma mark - CoreHaptics 高级震动引擎
static void InitHapticEngine(void) {
    if (sharedHapticEngine) return;
    if (@available(iOS 13.0, *)) {
        if (!CHHapticEngine.capabilitiesForHardware.supportsHaptics) return;
        NSError *err = nil;
        sharedHapticEngine = [[CHHapticEngine alloc] initAndReturnError:&err];
        if (err || !sharedHapticEngine) return;
        sharedHapticEngine.resetHandler = ^{
            [sharedHapticEngine startAndReturnError:nil];
        };
    }
}

static void PlayStrongHaptic(void) {
    if (@available(iOS 13.0, *)) {
        if (!sharedHapticEngine) {
            UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
            [gen prepare];
            [gen impactOccurred];
            return;
        }
        NSError *err = nil;
        CHHapticEventParameter *intensity = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:1.0];
        CHHapticEventParameter *sharpness = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:1.0];
        CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[intensity, sharpness] relativeTime:0 duration:0.6];
        CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&err];
        if (!err) {
            [sharedHapticEngine startAndReturnError:nil];
            id<CHHapticPatternPlayer> player = [sharedHapticEngine createPlayerWithPattern:pattern error:&err];
            if (!err) {
                [player startAtTime:0 error:&err];
            }
        }
    }
}

#pragma mark - 时间电量刷新（原版代码完全未修改）
static void RefreshTimeBatteryLabel(void) {
    if (!g_timeBatteryLabel) return;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm";
    NSString *timeStr = [fmt stringFromDate:[NSDate date]];

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    NSInteger batteryPercent = roundf([UIDevice currentDevice].batteryLevel * 100);
    g_timeBatteryLabel.text = [NSString stringWithFormat:@"%@ • %ld%%", timeStr, (long)batteryPercent];
}

%hook UILabel
- (void)didMoveToSuperview {
    %orig;
    CGRect frm = self.frame;
    if ((int)frm.size.width == 50 && (int)frm.size.height == 20 && !g_timeBatteryLabel) {
        g_timeBatteryLabel = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if(g_refreshTimer) [g_refreshTimer invalidate];
            g_refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                RefreshTimeBatteryLabel();
            }];
            RefreshTimeBatteryLabel();
        });
    }
}
%end

#pragma mark - 获取顶层控制器（弹窗必备）
static UIViewController* getTopViewController(void) {
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

%hook UIView
%new
// ✅ 长按弹出自定义选择菜单（恢复之前可用方案）
- (void)tweakLongPressAction:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state != UIGestureRecognizerStateBegan) return;
    UIView *floatBall = gesture.view;
    UIViewController *topVC = getTopViewController();
    if(!topVC) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"悬浮球菜单" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    // 选项1：隐藏悬浮球
    [alert addAction:[UIAlertAction actionWithTitle:@"隐藏悬浮球" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        floatBall.alpha = 0.02f;
    }]];
    // 选项2：打开原生菜单
    [alert addAction:[UIAlertAction actionWithTitle:@"打开原生菜单" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // 这里会放行触发系统原生长按菜单逻辑
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [topVC presentViewController:alert animated:YES completion:nil];
}

// ✅ 单击触发震动
- (void)tweakSingleTapAction:(UITapGestureRecognizer *)gesture {
    UIView *floatBall = gesture.view;
    if(floatBall.alpha > 0.5f) {
        PlayStrongHaptic();
    }
}

- (void)layoutSubviews {
    %orig;
    CGRect frm = self.frame;
    if (!((int)frm.size.width == 50 && (int)frm.size.height == 50)) return;

    // 清理旧手势，避免重复添加
    NSMutableArray *toRemove = [NSMutableArray array];
    for(UIGestureRecognizer *ges in self.gestureRecognizers) {
        if([ges isKindOfClass:[UILongPressGestureRecognizer class]] || [ges isKindOfClass:[UITapGestureRecognizer class]]) {
            [toRemove addObject:ges];
        }
    }
    for(UIGestureRecognizer *rGes in toRemove) {
        [self removeGestureRecognizer:rGes];
    }

    // 长按手势
    UILongPressGestureRecognizer *longTap = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tweakLongPressAction:)];
    longTap.minimumPressDuration = 0.25;
    longTap.cancelsTouchesInView = NO;
    [self addGestureRecognizer:longTap];

    // 单击震动手势
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tweakSingleTapAction:)];
    singleTap.numberOfTapsRequired = 1;
    singleTap.cancelsTouchesInView = NO;
    [self addGestureRecognizer:singleTap];
}
%end

%ctor {
    %init();
    dispatch_async(dispatch_get_main_queue(), ^{
        InitHapticEngine();
    });
}