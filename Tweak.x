#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>

@protocol CHHapticPatternPlayer;

static CHHapticEngine *sharedHapticEngine = nil;
static const NSInteger kTimeBatteryTag = 998877;
static NSTimer *labelRefreshTimer = nil;
static UILabel *g_timeBatLabel = nil;
static BOOL g_menuShow = NO;

#pragma mark - 震动引擎初始化
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

#pragma mark - 时间电量条控制
static void HideTimeBatLabel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(g_timeBatLabel) g_timeBatLabel.hidden = YES;
    });
}
static void ShowTimeBatLabel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(g_timeBatLabel) g_timeBatLabel.hidden = NO;
    });
}

#pragma mark - 刷新时间电量UI
static void RefreshLabel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(g_menuShow) return;
        __block UIView *floatBall = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *win in scene.windows) {
                __block void (^scanView)(UIView*) = nil;
                scanView = ^(UIView *view) {
                    if ([view isKindOfClass:UIImageView.class] && (int)view.bounds.size.width == 44 && (int)view.bounds.size.height == 44) {
                        floatBall = view;
                    }
                    for (UIView *subV in view.subviews) scanView(subV);
                };
                scanView(win);
                if(floatBall) break;
            }
            if(floatBall) break;
        }
        if(!floatBall) return;
        UIView *superV = floatBall.superview;
        if (!g_timeBatLabel) {
            g_timeBatLabel = [UILabel new];
            g_timeBatLabel.tag = kTimeBatteryTag;
            g_timeBatLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightMedium];
            g_timeBatLabel.textColor = UIColor.whiteColor;
            g_timeBatLabel.textAlignment = NSTextAlignmentCenter;
            g_timeBatLabel.backgroundColor = UIColor.clearColor;
            g_timeBatLabel.layer.zPosition = -10;
            g_timeBatLabel.userInteractionEnabled = NO;
            [superV addSubview:g_timeBatLabel];
        }
        CGRect ballFrame = floatBall.frame;
        g_timeBatLabel.frame = CGRectMake(ballFrame.origin.x - 30, ballFrame.origin.y + ballFrame.size.height + 6, 110, 24);

        NSDateFormatter *fmt = [NSDateFormatter new];
        fmt.dateFormat = @"HH:mm";
        NSString *timeStr = [fmt stringFromDate:NSDate.date];
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        NSInteger batVal = roundf([UIDevice currentDevice].batteryLevel * 100);
        g_timeBatLabel.text = [NSString stringWithFormat:@"%@ • %ld%%", timeStr, batVal];
    });
}

#pragma mark - 悬浮球Hook & 手势
%hook UIImageView
%new
- (void)shortLongPress:(UILongPressGestureRecognizer *)gest {
    if(gest.state != UIGestureRecognizerStateBegan) return;
    UIView *ball = self;
    if(ball.alpha > 0.5f) {
        // 球可见：长按隐藏
        ball.alpha = 0.02f;
    } else {
        // 球隐藏：长按恢复
        ball.alpha = 1.0f;
    }
}
- (void)doubleTapTriggerMenu:(UITapGestureRecognizer *)gest {
    UIView *ball = self;
    if(ball.alpha > 0.5f) return;
    // 仅隐藏状态双击唤起原生菜单
    for(UIGestureRecognizer *ges in ball.gestureRecognizers) {
        if([ges isKindOfClass:UILongPressGestureRecognizer.class]) {
            UILongPressGestureRecognizer *longGes = (UILongPressGestureRecognizer *)ges;
            longGes.state = UIGestureRecognizerStateBegan;
            longGes.state = UIGestureRecognizerStateRecognized;
            break;
        }
    }
    g_menuShow = YES;
    HideTimeBatLabel();
}

- (void)didMoveToWindow {
    %orig;
    UIView *view = self;
    if (!((int)view.bounds.size.width == 44 && (int)view.bounds.size.height == 44)) return;
    BOOL hasLongTap = NO;
    BOOL hasDoubleTap = NO;
    for(UIGestureRecognizer *g in view.gestureRecognizers) {
        if([g isKindOfClass:UILongPressGestureRecognizer.class]) {
            UILongPressGestureRecognizer *longG = (UILongPressGestureRecognizer *)g;
            if(longG.minimumPressDuration == 0.25) {
                hasLongTap = YES;
            }
        }
        if([g isKindOfClass:UITapGestureRecognizer.class]) {
            UITapGestureRecognizer *tapG = (UITapGestureRecognizer *)g;
            if(tapG.numberOfTapsRequired == 2) {
                hasDoubleTap = YES;
            }
        }
    }
    if(!hasLongTap) {
        UILongPressGestureRecognizer *longG = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(shortLongPress:)];
        longG.minimumPressDuration = 0.25;
        [view addGestureRecognizer:longG];
    }
    if(!hasDoubleTap) {
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapTriggerMenu:)];
        doubleTap.numberOfTapsRequired = 2;
        [view addGestureRecognizer:doubleTap];
    }
}
%end

// 菜单关闭，恢复时间电量条
%hook UIView
- (void)removeFromSuperview {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        g_menuShow = NO;
        ShowTimeBatLabel();
    });
}
%end

// 单击 CoreHaptics 强震动：强度1.0 / 锐度1.0 / 时长0.6s
%hook UITapGestureRecognizer
- (void)setState:(UIGestureRecognizerState)state {
    %orig;
    if(state != UIGestureRecognizerStateRecognized) return;
    UIView *tapView = self.view;
    if (!tapView) return;
    if (!([tapView isKindOfClass:UIImageView.class] && (int)tapView.bounds.size.width == 44 && (int)tapView.bounds.size.height == 44)) return;
    UITapGestureRecognizer *tapSelf = self;
    if(tapSelf.numberOfTapsRequired != 1 || tapSelf.enabled == NO) return;

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
%end

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        InitHapticEngine();
        if(labelRefreshTimer.isValid) [labelRefreshTimer invalidate];
        labelRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
            RefreshLabel();
        }];
    });
}