#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>

@protocol CHHapticPatternPlayer;

static CHHapticEngine *sharedHapticEngine = nil;
static const NSInteger kCustomTimeBatteryTag = 998877;
static NSTimer *floatLabelRefreshTimer = nil;
static UILabel *g_timeBatteryLabel = nil; // ✅ 全局缓存Label，只创建一次

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

static UIViewController* getTopViewController(void) {
    UIViewController *topVC = nil;
    for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *win in scene.windows) {
                if (win.isKeyWindow) {
                    topVC = win.rootViewController;
                    break;
                }
            }
        }
    }
    while(topVC && topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

static void setTapGestureEnable(UIView *floatView, BOOL enable) {
    for(UIGestureRecognizer *g in floatView.gestureRecognizers) {
        if([g isKindOfClass:[UITapGestureRecognizer class]]) {
            UITapGestureRecognizer *tapGes = (UITapGestureRecognizer *)g;
            if(tapGes.numberOfTapsRequired == 1) {
                tapGes.enabled = enable;
                break;
            }
        }
    }
}

// ✅ 直接返回缓存好的Label，不再遍历窗口查找
static UILabel* GetTimeBatteryLabel(void) {
    return g_timeBatteryLabel;
}

static void HideTimeBatteryLabel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *lb = GetTimeBatteryLabel();
        if(lb) {
            lb.hidden = YES;
            lb.layer.zPosition = -999;
        }
    });
}

static void ShowTimeBatteryLabel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *lb = GetTimeBatteryLabel();
        if(lb) {
            lb.hidden = NO;
            lb.layer.zPosition = 999;
        }
    });
}

static void showVisibleMenu(UIView *floatView) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"悬浮球操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *nativeMenuAction = [UIAlertAction actionWithTitle:@"打开原生菜单" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        for(UIGestureRecognizer *g in floatView.gestureRecognizers) {
            if([g isKindOfClass:[UILongPressGestureRecognizer class]]) {
                UILongPressGestureRecognizer *longGes = (UILongPressGestureRecognizer *)g;
                longGes.state = UIGestureRecognizerStateBegan;
                longGes.state = UIGestureRecognizerStateRecognized;
                break;
            }
        }
    }];
    
    UIAlertAction *hideBallAction = [UIAlertAction actionWithTitle:@"隐藏悬浮球" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        floatView.alpha = 0.02f;
        setTapGestureEnable(floatView, NO);
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        ShowTimeBatteryLabel();
    }];
    [alert addAction:nativeMenuAction];
    [alert addAction:hideBallAction];
    [alert addAction:cancelAction];
    
    UIViewController *topVC = getTopViewController();
    if(topVC) {
        [topVC presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - 刷新逻辑
static void RefreshFloatLabel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        __block UIView *floatBall = nil;
        for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *win in scene.windows) {
                __block void (^scanView)(UIView *) = nil;
                scanView = ^(UIView *view) {
                    if ([view isKindOfClass:[UIImageView class]]) {
                        if ((int)view.bounds.size.width == 44 && (int)view.bounds.size.height ==44) {
                            floatBall = view;
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
        
        // ✅ 如果Label还没有创建，一次性创建，之后永久复用
        if (!g_timeBatteryLabel) {
            g_timeBatteryLabel = [[UILabel alloc] init];
            g_timeBatteryLabel.tag = kCustomTimeBatteryTag;
            g_timeBatteryLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightMedium];
            g_timeBatteryLabel.textColor = [UIColor whiteColor];
            g_timeBatteryLabel.textAlignment = NSTextAlignmentCenter;
            g_timeBatteryLabel.backgroundColor = [UIColor clearColor];
            g_timeBatteryLabel.layer.zPosition = 999;
            g_timeBatteryLabel.userInteractionEnabled = NO;
            [parentView addSubview:g_timeBatteryLabel];
        }
        CGRect ballFrame = floatBall.frame;
        g_timeBatteryLabel.frame = CGRectMake(ballFrame.origin.x - 30, ballFrame.origin.y + ballFrame.size.height + 6, 110, 24);
        
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"HH:mm";
        NSString *timeStr = [fmt stringFromDate:[NSDate date]];
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        NSInteger bat = roundf([UIDevice currentDevice].batteryLevel * 100);
        g_timeBatteryLabel.text = [NSString stringWithFormat:@"%@ • %ld%%", timeStr, bat];
    });
}

#pragma mark - 悬浮球Hook
%hook UIImageView
%new
- (void)tweakLongPressAction:(UILongPressGestureRecognizer *)gesture {
    // ========== 只处理 Began 长按识别成功状态 ==========
    if(gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }
    UIView *floatView = self;
    if(floatView.alpha > 0.5f) {
        // ✅ 悬浮球可见长按：隐藏时间电量条，弹菜单
        HideTimeBatteryLabel();
        showVisibleMenu(floatView);
    } else {
        // ✅ 悬浮球处于隐藏状态长按：直接恢复悬浮球，时间条保持原样
        floatView.alpha = 1.0f;
        setTapGestureEnable(floatView, YES);
    }
}

- (void)didMoveToWindow {
    %orig;
    UIView *view = self;
    if (view.bounds.size.width == 44 && view.bounds.size.height == 44) {
        BOOL hasCustomLongPress = NO;
        for(UIGestureRecognizer *g in view.gestureRecognizers) {
            if([g isKindOfClass:[UILongPressGestureRecognizer class]]) {
                UILongPressGestureRecognizer *longG = (UILongPressGestureRecognizer *)g;
                if(longG.minimumPressDuration == 0.35f) {
                    hasCustomLongPress = YES;
                    break;
                }
            }
        }
        if(!hasCustomLongPress) {
            UILongPressGestureRecognizer *longTap = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tweakLongPressAction:)];
            longTap.minimumPressDuration = 0.35f;
            [view addGestureRecognizer:longTap];
        }
    }
}
%end

// Hook菜单View关闭事件
%hook UIView
- (void)removeFromSuperview {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        ShowTimeBatteryLabel();
    });
}
%end

%hook UITapGestureRecognizer
- (void)setState:(UIGestureRecognizerState)state {
    %orig;
    if(state == UIGestureRecognizerStateRecognized) {
        UIView *tapView = self.view;
        if (!tapView) return;
        if ([tapView isKindOfClass:[UIImageView class]] && tapView.bounds.size.width == 44 && tapView.bounds.size.height == 44) {
            UITapGestureRecognizer *tapSelf = self;
            if(tapSelf.numberOfTapsRequired == 1 && tapSelf.enabled) {
                if (@available(iOS 13.0, *)) {
                    if (!sharedHapticEngine) {
                        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
                        [gen prepare];
                        [gen impactOccurred];
                        return;
                    }
                    NSError *error = nil;
                    CHHapticEventParameter *intensityParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:1.0];
                    CHHapticEventParameter *sharpnessParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:1.0];
                    CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[intensityParam, sharpnessParam] relativeTime:0 duration:0.6];
                    CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];
                    if (!error) {
                        [sharedHapticEngine startAndReturnError:nil];
                        id<CHHapticPatternPlayer> player = [sharedHapticEngine createPlayerWithPattern:pattern error:&error];
                        if (!error) {
                            [player startAtTime:0 error:&error];
                        }
                    }
                }
            }
        }
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