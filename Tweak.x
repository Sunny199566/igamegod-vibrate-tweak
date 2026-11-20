#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>
#import <dispatch/dispatch.h>

static CHHapticEngine *sharedHapticEngine = nil;
static UILabel *g_timeBatteryLabel = nil;
static NSTimer *g_refreshTimer = nil;

// ========= 【新增：时间电量刷新函数，仅此新增，原有代码不动】 =========
static void RefreshTimeBatteryLabel(void) {
    if (!g_timeBatteryLabel) return;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm";
    NSString *timeStr = [fmt stringFromDate:[NSDate date]];

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    NSInteger batteryPercent = roundf([UIDevice currentDevice].batteryLevel * 100);
    g_timeBatteryLabel.text = [NSString stringWithFormat:@"%@ • %ld%%", timeStr, (long)batteryPercent];
}

static UIViewController* GetRootVC(void) {
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            UIWindow *win = scene.windows.firstObject;
            if(win.rootViewController) return win.rootViewController;
        }
    }
    return nil;
}

// ========= 【新增：Hook原生时间Label，创建独立UI，不修改原有悬浮球逻辑】 =========
%hook UILabel
- (void)didMoveToSuperview {
    %orig;
    CGRect frm = self.frame;
    if ((int)frm.size.width == 50 && (int)frm.size.height == 20 && (int)frm.origin.x == -3 && (int)frm.origin.y == 47) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(g_timeBatteryLabel) return;
            UIView *superV = self.superview;
            CGRect newFrame = CGRectMake(frm.origin.x, frm.origin.y, 90, 20);
            g_timeBatteryLabel = [[UILabel alloc] initWithFrame:newFrame];
            g_timeBatteryLabel.font = self.font;
            g_timeBatteryLabel.textColor = self.textColor;
            g_timeBatteryLabel.textAlignment = NSTextAlignmentRight;
            g_timeBatteryLabel.backgroundColor = [UIColor clearColor];
            [superV addSubview:g_timeBatteryLabel];
            
            if(g_refreshTimer) [g_refreshTimer invalidate];
            g_refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                RefreshTimeBatteryLabel();
            }];
            RefreshTimeBatteryLabel();
        });
    }
}
%end

// ========= 【你原来整套悬浮球+CoreHaptics震动+0.25s长按代码，原样完整保留，一行不改！】 =========
static void SetupHapticEngine(void) {
    if (sharedHapticEngine) return;
    NSError *err = nil;
    sharedHapticEngine = [[CHHapticEngine alloc] initWithAndReturnError:&err];
    if (sharedHapticEngine) {
        [sharedHapticEngine startWithCompletionHandler:nil];
    }
}

%hook UIView
%new
- (void)tweakLongPressAction:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state != UIGestureRecognizerStateBegan) return;
    UIView *floatBall = gesture.view;
    if(floatBall.alpha > 0.5f) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"悬浮球操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        [alert addAction:[UIAlertAction actionWithTitle:@"打开原生菜单" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            // 原生菜单回调，保持原样
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"隐藏悬浮球" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            floatBall.alpha = 0.02f;
            for(UIGestureRecognizer *ges in floatBall.gestureRecognizers) {
                if([ges isKindOfClass:[UITapGestureRecognizer class]]) {
                    ges.enabled = NO;
                }
            }
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        UIViewController *rootVC = GetRootVC();
        if(rootVC) {
            [rootVC presentViewController:alert animated:YES completion:nil];
        }
    } else {
        floatBall.alpha = 1.0f;
        for(UIGestureRecognizer *ges in floatBall.gestureRecognizers) {
            if([ges isKindOfClass:[UITapGestureRecognizer class]]) {
                ges.enabled = YES;
            }
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    CGRect frm = self.frame;
    if ((int)frm.size.width == 50 && (int)frm.size.height == 50) {
        SetupHapticEngine();
        // CoreHaptics震动逻辑，完全保留原版
        CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:0.6],
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.4]
        ] relativeTime:0 duration:0.12];
        NSError *err = nil;
        CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&err];
        if(pattern) {
            [sharedHapticEngine startPlayingPattern:pattern completionHandler:nil];
        }
    }
}

- (void)didMoveToSuperview {
    %orig;
    CGRect frm = self.frame;
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
    }
}
%end

%ctor {
    %init();
}