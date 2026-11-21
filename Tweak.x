#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>

static CHHapticEngine *sharedHapticEngine = nil;
static const NSInteger kCustomTimeBatteryTag = 998877;
static NSTimer *floatLabelRefreshTimer = nil;
static BOOL nativeMenuActive = NO;

static void SetupHapticEngine(void) {
    if (sharedHapticEngine != nil) return;
    if (@available(iOS 13.0, *)) {
        if (!CHHapticEngine.capabilitiesForHardware.supportsHaptics) return;
        NSError *error = nil;
        sharedHapticEngine = [[CHHapticEngine alloc] initAndReturnError:&error];
        if (error || !sharedHapticEngine) {
            sharedHapticEngine = nil;
            return;
        }
        sharedHapticEngine.resetHandler = ^{
            [sharedHapticEngine startAndReturnError:nil];
        };
    }
}

// ========== 你原来的高级震动：强度1.0，锐度1.0，持续0.6s ==========
static void PlayStrongHaptic(void) {
    if (!sharedHapticEngine) return;
    NSError *err = nil;
    CHHapticEventParameter *intensityParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:1.0f];
    CHHapticEventParameter *sharpnessParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:1.0f];
    CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient parameters:@[intensityParam, sharpnessParam] relativeTime:0.0f duration:0.6f];
    CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&err];
    if (err || !pattern) return;
    CHHapticPatternPlayer *player = [sharedHapticEngine createPlayerWithPattern:pattern error:&err];
    if (err || !player) return;
    [player startAtTime:0 error:&err];
}

static UILabel* getTimeLabel(void) {
    __block UILabel *resultLabel = nil;
    for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *win in scene.windows) {
            __block void (^scanView)(UIView *) = nil;
            scanView = ^(UIView *view) {
                if (resultLabel) return;
                if(view.tag == kCustomTimeBatteryTag) {
                    resultLabel = (UILabel *)view;
                    return;
                }
                for(UIView *sub in view.subviews) {
                    scanView(sub);
                }
            };
            scanView(win);
            if(resultLabel) break;
        }
        if(resultLabel) break;
    }
    return resultLabel;
}

static void RestoreTimeBatteryLabel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        nativeMenuActive = NO;
        UILabel *lb = getTimeLabel();
        if(lb) {
            lb.hidden = NO;
        }
    });
}

static void HideTimeBatteryLabel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        nativeMenuActive = YES;
        UILabel *lb = getTimeLabel();
        if(lb) {
            lb.hidden = YES;
        }
    });
}

#pragma mark - 时间电量刷新逻辑
static void RefreshFloatLabel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        __block UIView *floatBall = nil;
        for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *win in scene.windows) {
                __block void (^scanView)(UIView *) = nil;
                scanView = ^(UIView *view) {
                    if ([view isKindOfClass:NSClassFromString(@"AssistiveTouchButton")]) {
                        floatBall = view;
                    }
                    if ([view isKindOfClass:[UILabel class]]) {
                        UILabel *lb = (UILabel *)view;
                        if(lb.textColor == [UIColor whiteColor] && [lb.text containsString:@":"]){
                            lb.hidden = YES;
                            lb.userInteractionEnabled = NO;
                        }
                    }
                    for(UIView *sub in view.subviews) {
                        scanView(sub);
                    }
                };
                scanView(win);
                if(floatBall) break;
            }
            if(floatBall) break;
        }
        if(!floatBall) return;
        UIView *parentView = floatBall.superview;
        UILabel *customLabel = (UILabel *)[parentView viewWithTag:kCustomTimeBatteryTag];
        if (!customLabel) {
            CGRect ballFrame = floatBall.frame;
            CGRect labelFrame = CGRectMake(ballFrame.origin.x - 30, ballFrame.origin.y + ballFrame.size.height + 6, 110, 24);
            customLabel = [[UILabel alloc] initWithFrame:labelFrame];
            customLabel.tag = kCustomTimeBatteryTag;
            customLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightMedium];
            customLabel.textColor = [UIColor whiteColor];
            customLabel.textAlignment = NSTextAlignmentCenter;
            customLabel.backgroundColor = [UIColor clearColor];
            customLabel.userInteractionEnabled = NO;
            [parentView addSubview:customLabel];
        }
        CGRect ballFrame = floatBall.frame;
        customLabel.frame = CGRectMake(ballFrame.origin.x - 30, ballFrame.origin.y + ballFrame.size.height + 6, 110, 24);
        
        if(!nativeMenuActive){
            customLabel.hidden = NO;
        }
        
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"HH:mm";
        NSString *timeStr = [fmt stringFromDate:[NSDate date]];
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        NSInteger bat = roundf([UIDevice currentDevice].batteryLevel * 100);
        customLabel.text = [NSString stringWithFormat:@"%@ • %ld%%", timeStr, bat];
    });
}

// ========== 恢复悬浮球本体Hook：单击震动 + 原有长按隐藏逻辑 ==========
%hook AssistiveTouchButton

- (void)_handleSingleTap:(id)arg1 {
    %orig;
    PlayStrongHaptic();
}

- (void)_handleLongPress:(id)arg1 {
    %orig;
    // 原有的长按隐藏悬浮球逻辑，全部保留
}

%end

// ✅ Hook长按手势，菜单弹出瞬间隐藏时间电量文字
%hook UILongPressGestureRecognizer
- (void)setState:(UIGestureRecognizerState)state {
    %orig;
    UIView *targetView = self.view;
    if (!targetView) return;
    if ([targetView isKindOfClass:NSClassFromString(@"AssistiveTouchButton")]) {
        if(state == UIGestureRecognizerStateBegan) {
            HideTimeBatteryLabel();
        }
    }
}
%end

// ✅ Hook菜单关闭事件，恢复时间电量文字
%hook UIMenuController
- (void)setMenuVisible:(BOOL)menuVisible animated:(BOOL)animated {
    %orig;
    if(!menuVisible) {
        RestoreTimeBatteryLabel();
    }
}
%end

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        SetupHapticEngine();
        if(floatLabelRefreshTimer && floatLabelRefreshTimer.isValid){
            [floatLabelRefreshTimer invalidate];
            floatLabelRefreshTimer = nil;
        }
        floatLabelRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
            RefreshFloatLabel();
        }];
    });
}