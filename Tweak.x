#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <CoreHaptics/CoreHaptics.h>

@protocol CHHapticPatternPlayer;
static CHHapticEngine *sharedHapticEngine = nil;
static UILabel *g_timeBatteryLabel = nil;
static NSTimer *g_refreshTimer = nil;

// 手势静态引用，用来动态开关
static UILongPressGestureRecognizer *g_customLongPress = nil;
static UITapGestureRecognizer *g_singleTapHaptic = nil;
static UITapGestureRecognizer *g_doubleTapRestore = nil;

#pragma mark - CoreHaptics 震动引擎
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

#pragma mark - 强震动：强度1.0 / 锐度1.0 / 持续0.6s
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

#pragma mark - 时间电量刷新【原版代码完全未修改】
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
%hook UIView
%new
// ✅ 自定义长按：球显示状态 → 隐藏悬浮球，并且关闭自定义长按、单击震动
- (void)customLongPressAction:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state != UIGestureRecognizerStateBegan) return;
    UIView *floatBall = gesture.view;
    if(floatBall.alpha > 0.5f) {
        floatBall.alpha = 0.02f;
        // 隐藏后：关闭自定义长按 + 单击震动，只保留双击恢复
        g_customLongPress.enabled = NO;
        g_singleTapHaptic.enabled = NO;
        g_doubleTapRestore.enabled = YES;
    }
}

// ✅ 单击震动：仅球显示时生效
- (void)singleTapHapticAction:(UITapGestureRecognizer *)gesture {
    UIView *floatBall = gesture.view;
    if(floatBall.alpha > 0.5f) {
        PlayStrongHaptic();
    }
}

// ✅ 双击恢复悬浮球：恢复后，重新开启长按、单击震动，关闭双击手势
- (void)doubleTapRestoreAction:(UITapGestureRecognizer *)gesture {
    UIView *floatBall = gesture.view;
    if(floatBall.alpha <= 0.5f) {
        floatBall.alpha = 1.0f;
        g_customLongPress.enabled = YES;
        g_singleTapHaptic.enabled = YES;
        g_doubleTapRestore.enabled = NO;
    }
}

// ✅ 保留你原版 didMoveToSuperview，不修改为layoutSubviews
- (void)didMoveToSuperview {
    %orig;
    CGRect frm = self.frame;
    if (!((int)frm.size.width == 50 && (int)frm.size.height == 50)) return;

    // 防止重复添加手势，先移除旧手势
    NSMutableArray *removeList = [NSMutableArray array];
    for(UIGestureRecognizer *ges in self.gestureRecognizers) {
        if([ges isKindOfClass:[UILongPressGestureRecognizer class]] || [ges isKindOfClass:[UITapGestureRecognizer class]]) {
            [removeList addObject:ges];
        }
    }
    for(UIGestureRecognizer *rGes in removeList) {
        [self removeGestureRecognizer:rGes];
    }

    // 创建全部手势
    g_customLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(customLongPressAction:)];
    g_customLongPress.minimumPressDuration = 0.25;
    g_customLongPress.cancelsTouchesInView = NO;

    g_singleTapHaptic = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapHapticAction:)];
    g_singleTapHaptic.numberOfTapsRequired = 1;
    g_singleTapHaptic.cancelsTouchesInView = NO;

    g_doubleTapRestore = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapRestoreAction:)];
    g_doubleTapRestore.numberOfTapsRequired = 2;
    g_doubleTapRestore.cancelsTouchesInView = NO;

    // 手势互斥：双击识别失败，才触发单击
    [g_singleTapHaptic requireGestureRecognizerToFail:g_doubleTapRestore];

    // 初始状态：悬浮球可见，开启长按、单击震动；关闭双击
    g_customLongPress.enabled = YES;
    g_singleTapHaptic.enabled = YES;
    g_doubleTapRestore.enabled = NO;

    [self addGestureRecognizer:g_customLongPress];
    [self addGestureRecognizer:g_singleTapHaptic];
    [self addGestureRecognizer:g_doubleTapRestore];
}
%end

%ctor {
    %init();
    dispatch_async(dispatch_get_main_queue(), ^{
        InitHapticEngine();
    });
}