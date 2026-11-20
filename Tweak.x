#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>
#import <dispatch/dispatch.h>

static CHHapticEngine *sharedHapticEngine = nil;
static UILabel *g_timeBatteryLabel = nil;
static NSTimer *g_refreshTimer = nil;

// ========= 时间电量刷新（完全保留原样） =========
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

// ========= 【修正CoreHaptics方法签名，其余悬浮球长按逻辑全部不动！】 =========
static void SetupHapticEngine(void) {
    if (sharedHapticEngine) return;
    NSError *err = nil;
    // ✅ 修复：initAndReturnError，去掉多余With
    sharedHapticEngine = [[CHHapticEngine alloc] initAndReturnError:&err];
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
        NSError *err = nil;
        CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:0.6],
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.4]
        ] relativeTime:0 duration:0.12];
        CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&err];
        if(pattern) {
            // ✅ 修复：先创建player，再start
            id<CHHapticPatternPlayer> player = [sharedHapticEngine createPlayerWithPattern:pattern error:&err];
            if(player) {
                [player startWithCompletionHandler:nil];
            }
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