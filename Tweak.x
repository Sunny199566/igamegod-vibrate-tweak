#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <CoreHaptics/CoreHaptics.h>

@protocol CHHapticPatternPlayer;
static CHHapticEngine *sharedHapticEngine = nil;
static UILabel *g_timeBatteryLabel = nil;
static NSTimer *g_refreshTimer = nil;
static UITapGestureRecognizer *g_restoreDoubleTap = nil;

#pragma mark - CoreHaptics 震动引擎初始化
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

#pragma mark - 执行强震动 强度1.0 / 锐度1.0 / 0.6s
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

#pragma mark - 时间电量刷新（原版逻辑完全未修改）
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

#pragma mark - 悬浮球手势逻辑
static void setTapGestureEnable(UIView *ballView, BOOL enable) {
    for(UIGestureRecognizer *ges in ballView.gestureRecognizers) {
        if([ges isKindOfClass:[UITapGestureRecognizer class]] && ges != g_restoreDoubleTap) {
            ges.enabled = enable;
        }
    }
}

%hook UIView
%new
// 长按逻辑：显示状态长按隐藏，隐藏状态放行原生菜单
- (void)tweakLongPressAction:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state != UIGestureRecognizerStateBegan) return;
    UIView *floatBall = gesture.view;
    if(floatBall.alpha > 0.5f) {
        floatBall.alpha = 0.02f;
        setTapGestureEnable(floatBall, NO);
    }
}

// ✅ 修改为【双击】恢复悬浮球
- (void)restoreBallDoubleTap:(UITapGestureRecognizer *)gesture {
    UIView *floatBall = gesture.view;
    if(floatBall.alpha <= 0.5f) {
        floatBall.alpha = 1.0f;
        setTapGestureEnable(floatBall, YES);
    }
}

- (void)didMoveToSuperview {
    %orig;
    CGRect frm = self.frame;
    // 原版悬浮球判断：50 × 50
    if ((int)frm.size.width == 50 && (int)frm.size.height == 50) {
        BOOL hasLongPress = NO;
        for(UIGestureRecognizer *ges in self.gestureRecognizers) {
            if([ges isKindOfClass:[UILongPressGestureRecognizer class]]) {
                UILongPressGestureRecognizer *lpGes = (UILongPressGestureRecognizer *)ges;
                if(lpGes.minimumPressDuration == 0.25f) {
                    hasLongPress = YES;
                    break;
                }
            }
        }
        if(!hasLongPress) {
            UILongPressGestureRecognizer *longTap = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tweakLongPressAction:)];
            longTap.minimumPressDuration = 0.25f;
            [self addGestureRecognizer:longTap];
        }
        // ✅ 双击手势 numberOfTapsRequired = 2
        if(!g_restoreDoubleTap) {
            g_restoreDoubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(restoreBallDoubleTap:)];
            g_restoreDoubleTap.numberOfTapsRequired = 2;
            [self addGestureRecognizer:g_restoreDoubleTap];
        }
    }
}
%end

// ✅ Hook原生单击手势，悬浮球可见时触发高级震动
%hook UITapGestureRecognizer
- (void)setState:(UIGestureRecognizerState)state {
    %orig;
    if(state != UIGestureRecognizerStateRecognized) return;
    UIView *tapView = self.view;
    if (!tapView) return;
    CGRect frm = tapView.frame;
    if (!([tapView isKindOfClass:[UIView class]] && (int)frm.size.width == 50 && (int)frm.size.height == 50)) return;
    UITapGestureRecognizer *tapSelf = self;
    if(tapSelf.numberOfTapsRequired != 1 || tapSelf.enabled == NO) return;

    // 跳过我们自己添加的双击手势
    if (tapSelf == g_restoreDoubleTap) return;
    // 只有悬浮球显示的时候才震动
    if(tapView.alpha <= 0.5f) return;

    PlayStrongHaptic();
}
%end

%ctor {
    %init();
    dispatch_async(dispatch_get_main_queue(), ^{
        InitHapticEngine();
    });
}