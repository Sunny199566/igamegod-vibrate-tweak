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
        
        // ✅ 定时器只在菜单关闭时打开文字，菜单打开状态完全不改动hidden属性
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

// ✅ Hook悬浮球原生长按手势回调，这才是原生菜单触发点！
%hook UILongPressGestureRecognizer
- (void)setState:(UIGestureRecognizerState)state {
    %orig;
    UIView *targetView = self.view;
    if (!targetView) return;
    // 判断：目标是悬浮球（44x44 UIImageView）
    if ([targetView isKindOfClass:[UIImageView class]] && (int)targetView.bounds.size.width ==44 && (int)targetView.bounds.size.height ==44) {
        if(state == UIGestureRecognizerStateBegan) {
            // ✅ 原生长按开始，立刻隐藏时间电量文字
            HideTimeBatteryLabel();
        }
    }
}
%end

// ✅ Hook UIMenuController（原生菜单关闭事件），菜单消失恢复文字
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