#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>

static CHHapticEngine *sharedHapticEngine = nil;

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

static void PlayCustomHaptic(void) {
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

static void showVisibleMenu(UIView *floatView) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"悬浮球操作" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *nativeMenuAction = [UIAlertAction actionWithTitle:@"打开原生菜单" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // 触发IGG原生长按菜单
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
        // 手势保持启用，不做禁用
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:nativeMenuAction];
    [alert addAction:hideAction];
    [alert addAction:cancelAction];
    
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while(topVC.presentedViewController) topVC = topVC.presentedViewController;
    [topVC presentViewController:alert animated:YES completion:nil];
}

%hook UIImageView
%new
- (void)tweakLongPressAction:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state != UIGestureRecognizerStateBegan) return;
    UIView *floatView = self;
    if(floatView.alpha > 0.5f) {
        // 显示状态：弹出选择菜单
        showVisibleMenu(floatView);
    } else {
        // 隐藏状态：直接恢复显示，无弹窗
        floatView.alpha = 1.0f;
    }
}

- (void)didMoveToWindow {
    %orig;
    UIView *view = self;
    if (view.bounds.size.width == 44 && view.bounds.size.height == 44) {
        BOOL hasCustomLongPress = NO;
        for(UIGestureRecognizer *g in view.gestureRecognizers) {
            if([g isKindOfClass:[UILongPressGestureRecognizer class]] && g.minimumPressDuration == 0.35f) {
                hasCustomLongPress = YES;
                break;
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
            if(tapSelf.numberOfTapsRequired == 1) {
                // ✅ 关键判断：只有悬浮球可见的时候才执行震动脚本，隐藏状态直接跳过，防止误触
                if (tapView.alpha > 0.5f) {
                    SetupHapticEngine();
                    PlayCustomHaptic();
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