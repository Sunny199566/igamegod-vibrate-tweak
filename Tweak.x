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

%hook UIImageView
%new
- (void)igod_doubleTapToggle:(UITapGestureRecognizer *)gesture {
    UIView *targetView = gesture.view;
    // ✅ 关键：0.02 > 0.01，绕过iOS hitTest过滤！触摸拖拽永久有效
    if(targetView.alpha > 0.5f) {
        targetView.alpha = 0.02f;
    } else {
        targetView.alpha = 1.0f;
    }
    PlayCustomHaptic();
}

- (void)didMoveToWindow {
    %orig;
    UIView *view = self;
    if (view.bounds.size.width == 44 && view.bounds.size.height == 44) {
        BOOL existDoubleTap = NO;
        for(UIGestureRecognizer *g in view.gestureRecognizers) {
            if([g isKindOfClass:[UITapGestureRecognizer class]] && ((UITapGestureRecognizer*)g).numberOfTapsRequired == 2) {
                existDoubleTap = YES;
                break;
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
        UIView *tapView = self.view;
        if (!tapView) return;
        if ([tapView isKindOfClass:[UIImageView class]] && tapView.bounds.size.width == 44 && tapView.bounds.size.height == 44) {
            // >0.5判定不变，0.02状态不会触发单击震动
            if(tapView.alpha > 0.5f) {
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