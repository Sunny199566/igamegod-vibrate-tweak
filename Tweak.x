#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>

static CHHapticEngine *sharedHapticEngine = nil;
static const NSInteger kCustomTimeBatteryTag = 998877;

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

#pragma mark - 【新增】状态栏时间电量Hook（完全独立，不干扰悬浮球代码）
%hook UILabel
- (void)didMoveToSuperview {
    %orig;
    CGRect frm = self.frame;
    // 匹配状态栏原生时间Label坐标尺寸：宽50，高20，x=-3,y=47
    if ((int)frm.size.width == 50 && (int)frm.size.height == 20 && (int)frm.origin.x == -3 && (int)frm.origin.y == 47) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.alpha = 0.0f;
            UIView *superV = self.superview;
            if(!superV) return;
            UILabel *existLabel = (UILabel *)[superV viewWithTag:kCustomTimeBatteryTag];
            if(existLabel) return;

            CGRect newFrame = CGRectMake(frm.origin.x, frm.origin.y, 90, 20);
            UILabel *customLabel = [[UILabel alloc] initWithFrame:newFrame];
            customLabel.tag = kCustomTimeBatteryTag;
            customLabel.font = self.font;
            customLabel.textColor = self.textColor;
            customLabel.textAlignment = NSTextAlignmentRight;
            customLabel.backgroundColor = [UIColor clearColor];
            [superV addSubview:customLabel];

            static NSTimer *timer = nil;
            if(timer) [timer invalidate];
            timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                UIViewController *topVC = getTopViewController();
                if(!topVC || !topVC.view.window) return;
                UILabel *lb = (UILabel *)[topVC.view.window viewWithTag:kCustomTimeBatteryTag];
                if(!lb) return;
                NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
                fmt.dateFormat = @"HH:mm";
                NSString *timeStr = [fmt stringFromDate:[NSDate date]];
                [UIDevice currentDevice].batteryMonitoringEnabled = YES;
                NSInteger bat = roundf([UIDevice currentDevice].batteryLevel * 100);
                lb.text = [NSString stringWithFormat:@"%@ • %ld%%", timeStr, (long)bat];
            }];
        });
    }
}
%end

#pragma mark - 原有悬浮球代码【完全原样保留，一行不改】
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
                // 直接在这里执行震动逻辑，不再单独调用闲置函数
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
    });
}