#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>

static CHHapticEngine *sharedHapticEngine = nil;
static BOOL isDoubleTapTriggered = NO;

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

%hook UIImageView
%new
- (void)igod_doubleTapToggle:(UITapGestureRecognizer *)gesture {
    // ✅ 【核心修复】一进入双击回调立刻上锁，窗口期拉长，覆盖单击识别时序
    isDoubleTapTriggered = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        isDoubleTapTriggered = NO;
    });

    UIView *targetView = gesture.view;
    UITapGestureRecognizer *singleTap = nil;
    UILongPressGestureRecognizer *longPressTap = nil;

    for(UIGestureRecognizer *g in targetView.gestureRecognizers) {
        if([g isKindOfClass:[UITapGestureRecognizer class]]) {
            UITapGestureRecognizer *tap = (UITapGestureRecognizer *)g;
            if(tap.numberOfTapsRequired == 1) {
                singleTap = tap;
            }
        }else if([g isKindOfClass:[UILongPressGestureRecognizer class]]) {
            longPressTap = (UILongPressGestureRecognizer *)g;
        }
    }

    if(targetView.alpha > 0.5f) {
        targetView.alpha = 0.02f;
        if(singleTap) singleTap.enabled = NO;
        if(longPressTap) longPressTap.enabled = NO;
    } else {
        targetView.alpha = 1.0f;
        if(singleTap) singleTap.enabled = YES;
        if(longPressTap) longPressTap.enabled = YES;
    }
    PlayCustomHaptic();
}

- (void)didMoveToWindow {
    %orig;
    UIView *view = self;
    if (view.bounds.size.width == 44 && view.bounds.size.height == 44) {
        UITapGestureRecognizer *existDoubleTap = nil;
        for(UIGestureRecognizer *g in view.gestureRecognizers) {
            if([g isKindOfClass:[UITapGestureRecognizer class]]) {
                UITapGestureRecognizer *tap = (UITapGestureRecognizer *)g;
                if(tap.numberOfTapsRequired == 2) {
                    existDoubleTap = tap;
                    break;
                }
            }
        }
        if(!existDoubleTap) {
            UITapGestureRecognizer *dtap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(igod_doubleTapToggle:)];
            dtap.numberOfTapsRequired = 2;
            dtap.cancelsTouchesInView = NO;
            [view addGestureRecognizer:dtap];
        }
    }
}
%end

%hook UITapGestureRecognizer
- (void)setState:(UIGestureRecognizerState)state {
    %orig;
    if(state == UIGestureRecognizerStateRecognized) {
        // ✅ 只要处于双击屏蔽窗口期，直接return，完全不执行脚本
        if(isDoubleTapTriggered) return;

        UIView *tapView = self.view;
        if (!tapView) return;
        if ([tapView isKindOfClass:[UIImageView class]] && tapView.bounds.size.width == 44 && tapView.bounds.size.height == 44) {
            UITapGestureRecognizer *tapSelf = (UITapGestureRecognizer *)self;
            if(tapSelf.numberOfTapsRequired == 1 && tapView.alpha > 0.5f) {
                SetupHapticEngine();
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