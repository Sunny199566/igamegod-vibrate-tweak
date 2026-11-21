#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>

static UILabel *g_timeBatteryLabel = nil;
static NSTimer *g_refreshTimer = nil;
static UITapGestureRecognizer *g_restoreTap = nil;

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
    // 精准匹配控件：width=50 height=20 【完全保留你原版时间电量代码，一行不动】
    if ((int)frm.size.width == 50 && (int)frm.size.height == 20 && !g_timeBatteryLabel) {
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

// ====== 悬浮球手势【基于你原版UIView hook修改，保留原有框架】======
static void setTapGestureEnable(UIView *ballView, BOOL enable) {
    for(UIGestureRecognizer *ges in ballView.gestureRecognizers) {
        if([ges isKindOfClass:[UITapGestureRecognizer class]] && ges != g_restoreTap) {
            ges.enabled = enable;
        }
    }
}

%hook UIView
%new
// ✅ 修改后长按逻辑：删除Alert弹窗
- (void)tweakLongPressAction:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state != UIGestureRecognizerStateBegan) return;
    UIView *floatBall = gesture.view;
    if(floatBall.alpha > 0.5f) {
        // ✅ 球可见：长按直接隐藏悬浮球
        floatBall.alpha = 0.02f;
        setTapGestureEnable(floatBall, NO);
    }
    // ✅ 球隐藏状态：直接不做任何处理，系统原生长按手势执行，弹出原生菜单
}

// ✅ 新增：隐藏状态单击恢复悬浮球
- (void)restoreBallTap:(UITapGestureRecognizer *)gesture {
    UIView *floatBall = gesture.view;
    if(floatBall.alpha <= 0.5f) {
        floatBall.alpha = 1.0f;
        setTapGestureEnable(floatBall, YES);
    }
}

- (void)didMoveToSuperview {
    %orig;
    CGRect frm = self.frame;
    // 悬浮球尺寸判断：保留你原版的 50 × 50
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
        // 添加恢复单击手势，只创建一次
        if(!g_restoreTap) {
            g_restoreTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(restoreBallTap:)];
            [self addGestureRecognizer:g_restoreTap];
        }
    }
}
%end

%ctor {
    %init();
}