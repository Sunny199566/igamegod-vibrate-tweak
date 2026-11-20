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

// 双击回调：切换显示隐藏
static void HandleDoubleTap(UITapGestureRecognizer *gesture) {
    UIView *targetView = gesture.view;
    targetView.alpha = (targetView.alpha > 0.5f) ? 0.0f : 1.0f;
    PlayCustomHaptic();
}

%hook UIImageView
- (void)didMoveToWindow {
    %orig;
    UIView *view = self;
    // 匹配目标悬浮图标 44*44
    if (view.bounds.size.width == 44 && view.bounds.size.height == 44) {
        // 防止重复添加手势
        BOOL hasDoubleTap = NO;
        for (UIGestureRecognizer *ges in view.gestureRecognizers) {
            if ([ges isKindOfClass:[UITapGestureRecognizer class]] && ((UITapGestureRecognizer *)ges).numberOfTapsRequired == 2) {
                hasDoubleTap = YES;
                break;
            }
        }
        if (!hasDoubleTap) {
            UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(HandleDoubleTap:)];
            doubleTap.numberOfTapsRequired = 2;
            // 关键配置：不拦截原有触摸事件，iGameGod自带单击/长按完全正常工作
            doubleTap.cancelsTouchesInView = NO;
            [view addGestureRecognizer:doubleTap];
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
            // 只有可见状态单击才震动+触发脚本，透明隐藏状态单击无效
            if (tapView.alpha > 0.5f) {
                PlayCustomHaptic();
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