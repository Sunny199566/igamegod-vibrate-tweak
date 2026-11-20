#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>

static UILabel *g_timeBatteryLabel = nil;
static NSTimer *g_refreshTimer = nil;

static void RefreshTimeBatteryLabel(void) {
    if (!g_timeBatteryLabel) return;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm";
    NSString *timeStr = [fmt stringFromDate:[NSDate date]];

    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    NSInteger batteryPercent = roundf([UIDevice currentDevice].batteryLevel * 100);
    g_timeBatteryLabel.text = [NSString stringWithFormat:@"%@ • %ld%%", timeStr, (long)batteryPercent];
}

%hook UILabel
- (void)didMoveToSuperview {
    %orig;
    CGRect frm = self.frame;
    // 精准匹配：宽50，高20，坐标(-3,47)，和你截图完全一致
    if ((int)frm.size.width == 50 && (int)frm.size.height == 20 && (int)frm.origin.x == -3 && (int)frm.origin.y == 47 && !g_timeBatteryLabel) {
        g_timeBatteryLabel = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if(g_refreshTimer) [g_refreshTimer invalidate];
            g_refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                RefreshTimeBatteryLabel();
            }];
            RefreshTimeBatteryLabel();
        });
    }
}
%end

// ====== 悬浮球长按0.25s逻辑（修复keyWindow废弃问题）======
static void setTapGestureEnable(UIView *ballView, BOOL enable) {
    for(UIGestureRecognizer *ges in ballView.gestureRecognizers) {
        if([ges isKindOfClass:[UITapGestureRecognizer class]]) {
            ges.enabled = enable;
        }
    }
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

%hook UIView
%new
- (void)tweakLongPressAction:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state != UIGestureRecognizerStateBegan) return;
    UIView *floatBall = gesture.view;
    if(floatBall.alpha > 0.5f) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"悬浮球操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        [alert addAction:[UIAlertAction actionWithTitle:@"打开原生菜单" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            // 原生菜单逻辑，按需自行补充
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"隐藏悬浮球" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            floatBall.alpha = 0.02f;
            setTapGestureEnable(floatBall, NO);
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        UIViewController *rootVC = GetRootVC();
        if(rootVC) {
            [rootVC presentViewController:alert animated:YES completion:nil];
        }
    } else {
        floatBall.alpha = 1.0f;
        setTapGestureEnable(floatBall, YES);
    }
}

- (void)didMoveToSuperview {
    %orig;
    CGRect frm = self.frame;
    // 这里替换成你的悬浮球真实宽高，你可以从视图调试工具查看圆球size修改
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