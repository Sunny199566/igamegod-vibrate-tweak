#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>

static CHHapticEngine *sharedHapticEngine = nil;
static const NSInteger kCustomTimeBatteryTag = 998877;
static NSTimer *g_refreshTimer = nil;
static BOOL g_menuIsOpen = NO;

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
    UIWindow *keyWindow = nil;
    for (UIWindow *w in [UIApplication sharedApplication].connectedScenes) {
        if ([w isKindOfClass:[UIWindow class]] && w.isKeyWindow) {
            keyWindow = w;
            break;
        }
    }
    UIViewController *rootVC = keyWindow.rootViewController;
    topVC = rootVC;
    while(topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

static void setTapGestureEnable(UIView *floatView, BOOL enable) {
    for(UIGestureRecognizer *ges in floatView.gestureRecognizers) {
        if([ges isKindOfClass:[UITapGestureRecognizer class]]) {
            ges.enabled = enable;
        }
    }
}

static UILabel* getTimeBatteryLabel(void) {
    UIView *floatBall = nil;
    // 查找悬浮球（44*44 ImageView）
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        for (UIView *subview in window.subviews) {
            if ([subview isKindOfClass:[UIImageView class]] && subview.bounds.size.width >=40 && subview.bounds.size.width <=50) {
                floatBall = subview;
                break;
            }
        }
        if(floatBall) break;
    }
    if(!floatBall) return nil;
    UILabel *label = [floatBall viewWithTag:kCustomTimeBatteryTag];
    if(!label) {
        label = [[UILabel alloc] init];
        label.tag = kCustomTimeBatteryTag;
        label.font = [UIFont systemFontOfSize:22 weight:UIFontWeightMedium];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.backgroundColor = [UIColor clearColor];
        label.layer.zPosition = 999;
        [floatBall addSubview:label];
    }
    // 定位：悬浮球正下方，你后面可以自行调整x偏移
    CGRect ballFrame = floatBall.frame;
    label.frame = CGRectMake(-30, ballFrame.size.height + 2, 110, 24);
    return label;
}

static void updateTimeBatteryText(void) {
    if(g_menuIsOpen) return;
    UILabel *lb = getTimeBatteryLabel();
    if(!lb) return;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm";
    NSString *timeStr = [fmt stringFromDate:[NSDate date]];
    float battery = [UIDevice currentDevice].batteryLevel;
    int batPercent = (int)(battery * 100);
    lb.text = [NSString stringWithFormat:@"%@ %d%%", timeStr, batPercent];
    lb.hidden = NO;
}

#pragma mark - Hook 老贝贝连点器 MainViewController (Swift特殊类名动态绑定)
%hook MainViewControllerProxy
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    g_menuIsOpen = YES;
    UILabel *lb = getTimeBatteryLabel();
    if(lb) lb.hidden = YES;
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    g_menuIsOpen = NO;
    UILabel *lb = getTimeBatteryLabel();
    if(lb) lb.hidden = NO;
}
%end

static void showFloatMenu(UIView *floatView) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *openNative = [UIAlertAction actionWithTitle:@"打开原生菜单" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        // 调用打开老贝贝悬浮菜单逻辑
    }];
    UIAlertAction *hideBall = [UIAlertAction actionWithTitle:@"隐藏悬浮球" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        floatView.alpha = 0.02f;
        setTapGestureEnable(floatView, NO);
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:openNative];
    [alert addAction:hideBall];
    [alert addAction:cancel];
    [getTopViewController() presentViewController:alert animated:YES completion:nil];
}

#pragma mark 悬浮球手势Hook
%hook UIImageView
%new
- (void)longPressHandler:(UILongPressGestureRecognizer *)ges {
    if(ges.state != UIGestureRecognizerStateBegan) return;
    showFloatMenu(self);
}
- (void)tapVibrate:(UITapGestureRecognizer *)ges {
    if (@available(iOS 13.0, *)) {
        if(sharedHapticEngine) {
            NSError *err = nil;
            // 强度1.0，锐度1.0，持续0.6s
            CHHapticEventParameter *intensityParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:1.0f];
            CHHapticEventParameter *sharpParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:1.0f];
            CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[intensityParam, sharpParam] relativeTime:0 duration:0.6f];
            CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] curves:@[] error:&err];
            if(!err) {
                [sharedHapticEngine playPattern:pattern error:&err];
            }
        }
    }
}
%end

%ctor {
    SetupHapticEngine();
    // ✅ 动态绑定Swift类！核心：把MainViewControllerProxy映射到真实的Swift MainViewController类
    Class realVCClass = objc_getClass("ÊÇ®È±°.MainViewController");
    if(realVCClass) {
        %init(MainViewControllerProxy = realVCClass);
    }
    // 定时器刷新时间电量
    g_refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
        updateTimeBatteryText();
    }];
    [[NSRunLoop mainRunLoop] addTimer:g_refreshTimer forMode:NSRunLoopCommonModes];
}