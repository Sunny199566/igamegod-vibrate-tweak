#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>
#import <dispatch/dispatch.h>

static CHHapticEngine *sharedHapticEngine = nil;
static const NSInteger kCustomTimeBatteryTag = 998877;

static UIView* GetKeyWindow(void) {
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *win in scene.windows) {
                if (win.isKeyWindow) return win;
            }
        }
    }
    return nil;
}

// ========= 时间电量刷新 =========
static void RefreshTimeBatteryLabel(void) {
    UIWindow *keyWin = (UIWindow *)GetKeyWindow();
    if(!keyWin) return;
    UILabel *customLabel = (UILabel *)[keyWin viewWithTag:kCustomTimeBatteryTag];
    if (!customLabel) return;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm";
    NSString *timeStr = [fmt stringFromDate:[NSDate date]];

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    NSInteger batteryPercent = roundf([UIDevice currentDevice].batteryLevel * 100);
    customLabel.text = [NSString stringWithFormat:@"%@ • %ld%%", timeStr, (long)batteryPercent];
}

static UIViewController* GetRootVC(void) {
    UIWindow *keyWin = (UIWindow *)GetKeyWindow();
    if(keyWin) return keyWin.rootViewController;
    return nil;
}

%hook UILabel
- (void)didMoveToSuperview {
    %orig;
    CGRect frm = self.frame;
    // 命中原生时间Label
    if ((int)frm.size.width == 50 && (int)frm.size.height == 20 && (int)frm.origin.x == -3 && (int)frm.origin.y == 47) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // ✅ 直接隐藏原生时间文字，解决双重显示
            self.alpha = 0.0f;

            UIView *superV = self.superview;
            if(!superV) return;
            // ✅ 根据tag判断是否已经创建，防止重复创建长条错位
            UILabel *existLabel = (UILabel *)[superV viewWithTag:kCustomTimeBatteryTag];
            if(existLabel) return;

            CGRect newFrame = CGRectMake(frm.origin.x, frm.origin.y, 90, 20);
            UILabel *g_timeBatteryLabel = [[UILabel alloc] initWithFrame:newFrame];
            g_timeBatteryLabel.tag = kCustomTimeBatteryTag;
            g_timeBatteryLabel.font = self.font;
            g_timeBatteryLabel.textColor = self.textColor;
            g_timeBatteryLabel.textAlignment = NSTextAlignmentRight;
            g_timeBatteryLabel.backgroundColor = [UIColor clearColor];
            [superV addSubview:g_timeBatteryLabel];

            // 定时器刷新
            static NSTimer *timer = nil;
            if(timer) [timer invalidate];
            timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                RefreshTimeBatteryLabel();
            }];
            RefreshTimeBatteryLabel();
        });
    }
}
%end

// ========= CoreHaptics 引擎初始化 =========
static void SetupHapticEngine(void) {
    if (sharedHapticEngine) return;
    NSError *err = nil;
    sharedHapticEngine = [[CHHapticEngine alloc] initAndReturnError:&err];
    if (sharedHapticEngine) {
        [sharedHapticEngine startAndReturnError:&err];
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
        if(!sharedHapticEngine) return;
        NSError *err = nil;
        // ✅ 保留你原始参数：强度1.0，锐度1.0，持续0.6s
        CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:1.0f],
            [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:1.0f]
        ] relativeTime:0 duration:0.6];
        CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&err];
        if(pattern) {
            id<CHHapticPatternPlayer> player = [sharedHapticEngine createPlayerWithPattern:pattern error:&err];
            if(player) {
                [player startAtTime:CHHapticTimeImmediate error:&err];
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
            longTap.allowableMovement = 10.0f;
            [self addGestureRecognizer:longTap];
        }
    }
}
%end

%ctor {
    %init();
}