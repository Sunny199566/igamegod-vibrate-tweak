#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>

static CHHapticEngine *sharedHapticEngine = nil;
static const NSInteger kCustomTimeBatteryTag = 998877;
static NSTimer *floatLabelRefreshTimer = nil;

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
    
    UIAlertAction *hideAction = [UIAlertAction actionWithTitle:@"隐藏悬浮球" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        floatView.alpha = 0.02f;
        setTapGestureEnable(floatView, NO);
        UILabel *lab = (UILabel *)[floatView.superview viewWithTag:kCustomTimeBatteryTag];
        if(lab) lab.hidden = YES;
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:nativeMenuAction];
    [alert addAction:hideAction];
    [alert addAction:cancelAction];
    
    UIViewController *topVC = getTopViewController();
    if(topVC) {
        [topVC presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - 每次刷新都强制隐藏iGameGod原生计时Label
static void RefreshFloatLabel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        __block UIView *floatBall = nil;
        for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *win in scene.windows) {
                __block void (^scanView)(UIView *) = nil;
                scanView = ^(UIView *view) {
                    // 找到悬浮球
                    if ([view isKindOfClass:[UIImageView class]]) {
                        if ((int)view.bounds.size.width == 44 && (int)view.bounds.size.height ==44) {
                            floatBall = view;
                        }
                    }
                    // 重点：每次扫描，只要发现带 ":" 的白色大号Label（iGameGod计时）立刻隐藏
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
            CGRect labelFrame = CGRectMake(ballFrame.origin.x - 35, ballFrame.origin.y + ballFrame.size.height + 8, 120, 28);
            customLabel = [[UILabel alloc] initWithFrame:labelFrame];
            customLabel.tag = kCustomTimeBatteryTag;
            customLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightMedium];
            customLabel.textColor = [UIColor whiteColor];
            customLabel.textAlignment = NSTextAlignmentCenter;
            customLabel.backgroundColor = [UIColor clearColor];
            // ✅修复：layer.zPosition
            customLabel.layer.zPosition = 999;
            customLabel.userInteractionEnabled = NO;
            [parentView addSubview:customLabel];
        }
        // 跟随悬浮球坐标更新位置
        CGRect ballFrame = floatBall.frame;
        customLabel.frame = CGRectMake(ballFrame.origin.x - 35, ballFrame.origin.y + ballFrame.size.height + 8, 120, 28);
        customLabel.hidden = (floatBall.alpha < 0.1f);
        
        // 渲染文字：HH:mm • 电量%
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"HH:mm";
        NSString *timeStr = [fmt stringFromDate:[NSDate date]];
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        NSInteger bat = roundf([UIDevice currentDevice].batteryLevel * 100);
        customLabel.text = [NSString stringWithFormat:@"%@ • %ld%%", timeStr, bat];
    });
}

#pragma mark - 悬浮球Hook
%hook UIImageView
%new
- (void)tweakLongPressAction:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state != UIGestureRecognizerStateBegan) return;
    UIView *floatView = self;
    if(floatView.alpha > 0.5f) {
        showVisibleMenu(floatView);
    } else {
        floatView.alpha = 1.0f;
        setTapGestureEnable(floatView, YES);
        UILabel *lab = (UILabel *)[floatView.superview viewWithTag:kCustomTimeBatteryTag];
        if(lab) lab.hidden = NO;
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
            UITapGestureRecognizer *tapSelf = (UITapGestureRecognizer *)self;
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
        // 先销毁旧定时器，防止多定时器同时运行（非常关键！）
        if(floatLabelRefreshTimer && floatLabelRefreshTimer.isValid){
            [floatLabelRefreshTimer invalidate];
            floatLabelRefreshTimer = nil;
        }
        floatLabelRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
            RefreshFloatLabel();
        }];
    });
}