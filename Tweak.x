#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>

@protocol CHHapticPatternPlayer;

static CHHapticEngine *sharedHapticEngine = nil;
static const NSInteger kCustomTimeBatteryTag = 998877;
static const NSInteger kNativeTimeHideTag = 998878;
static NSTimer *floatLabelRefreshTimer = nil;
static UILabel *g_timeBatteryLabel = nil;

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

static UILabel* GetTimeBatteryLabel(void) {
    return g_timeBatteryLabel;
}

static void HideTimeBatteryLabel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *lb = GetTimeBatteryLabel();
        if(lb) lb.hidden = YES;
    });
}

// 递归遍历视图，隐藏原生时间Label
static void HideNativeTimeLabel(UIView *rootView) {
    for (UIView *sub in rootView.subviews) {
        if ([sub isKindOfClass:[UILabel class]] && sub.tag != kCustomTimeBatteryTag && sub.tag != kNativeTimeHideTag) {
            UILabel *lb = (UILabel *)sub;
            // 特征：包含冒号，时间格式文本，就是原生时间
            if ([lb.text containsString:@":"]) {
                lb.hidden = YES;
                lb.tag = kNativeTimeHideTag;
            }
        }
        HideNativeTimeLabel(sub);
    }
}

#pragma mark - 检测连点器原生选择面板 frame(0,0,200,32)
static BOOL CheckPanelViewExist(void) {
    __block BOOL foundPanel = NO;
    for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *win in scene.windows) {
            __block void (^scanView)(UIView *) = nil;
            scanView = ^(UIView *view) {
                if ([view isKindOfClass:[UIView class]]) {
                    CGRect frm = view.frame;
                    // 增加±1容错，防止小数坐标识别失败
                    if( (abs((int)frm.origin.x - 0) <=1) && (abs((int)frm.origin.y -0) <=1) && (abs((int)frm.size.width -200) <=1) && (abs((int)frm.size.height -32) <=1) ){
                        foundPanel = YES;
                        return;
                    }
                }
                for(UIView *sub in view.subviews) {
                    scanView(sub);
                    if(foundPanel) return;
                }
            };
            scanView(win);
            if(foundPanel) break;
        }
        if(foundPanel) break;
    }
    return foundPanel;
}

#pragma mark - 刷新逻辑
static void RefreshFloatLabel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        // ✅ 仅判断原生200×32面板，我们自己的自定义菜单不再隐藏文字
        BOOL panelIsOpen = CheckPanelViewExist();
        if(panelIsOpen) {
            HideTimeBatteryLabel();
            return;
        }
        
        __block UIView *floatBall = nil;
        __block UIWindow *targetWindow = nil; // 加上 __block！修复编译报错
        for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *win in scene.windows) {
                __block void (^scanView)(UIView *) = nil;
                scanView = ^(UIView *view) {
                    if ([view isKindOfClass:[UIImageView class]]) {
                        if ((int)view.bounds.size.width == 44 && (int)view.bounds.size.height ==44) {
                            floatBall = view;
                            targetWindow = win;
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
        
        // 新增：每次扫描，自动隐藏原生时间文字
        if(targetWindow){
            HideNativeTimeLabel(targetWindow);
        }

        if (!g_timeBatteryLabel) {
            g_timeBatteryLabel = [[UILabel alloc] init];
            g_timeBatteryLabel.tag = kCustomTimeBatteryTag;
            g_timeBatteryLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
            g_timeBatteryLabel.textColor = [UIColor whiteColor];
            g_timeBatteryLabel.textAlignment = NSTextAlignmentCenter;
            g_timeBatteryLabel.backgroundColor = [UIColor clearColor];
            g_timeBatteryLabel.layer.zPosition = -10;
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
        g_timeBatteryLabel.hidden = NO;
    });
}

static void showVisibleMenu(UIView *floatView) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"悬浮球菜单" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *actionHideBall = [UIAlertAction actionWithTitle:@"隐藏悬浮球" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        floatView.alpha = 0.02f;
        setTapGestureEnable(floatView, NO);
    }];
    
    UIAlertAction *actionOpenNativeMenu = [UIAlertAction actionWithTitle:@"打开原生菜单" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // 唤起连点器原生长按逻辑，弹出那个200×32选择面板
        for(UIGestureRecognizer *g in floatView.gestureRecognizers) {
            if([g isKindOfClass:[UILongPressGestureRecognizer class]]) {
                UILongPressGestureRecognizer *longGes = (UILongPressGestureRecognizer *)g;
                longGes.state = UIGestureRecognizerStateBegan;
                longGes.state = UIGestureRecognizerStateRecognized;
                break;
            }
        }
    }];
    
    UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:actionHideBall];
    [alert addAction:actionOpenNativeMenu];
    [alert addAction:actionCancel];
    
    UIViewController *topVC = getTopViewController();
    if(topVC) {
        [topVC presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - 悬浮球Hook
%hook UIImageView
%new
- (void)tweakLongPressAction:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }
    UIView *floatView = self;
    if(floatView.alpha > 0.5f) {
        // ✅ 悬浮球可见：弹出自定义菜单，时间电量条保持显示，不会隐藏
        showVisibleMenu(floatView);
    } else {
        // ✅ 悬浮球隐藏状态长按：直接恢复悬浮球
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
        // 0.5s轮询；如果觉得还有延迟，可以改成0.2，响应更快，功耗几乎感知不到
        floatLabelRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
            RefreshFloatLabel();
        }];
    });
}