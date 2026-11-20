#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>

%hook UIGestureRecognizer
- (void)setState:(UIGestureRecognizerState)state {
    %orig;
    if(state == UIGestureRecognizerStateRecognized) {
        UIView *targetView = self.view;
        if(!targetView) return;
        UIWindow *win = targetView.window;
        if (!win) return;
        
        // ====== 你原来插件的高级震动逻辑，原样复用 ======
        if (@available(iOS 13.0, *)) {
            static CHHapticEngine *sharedHapticEngine = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                if (CHHapticEngine.capabilitiesForHardware.supportsHaptics) {
                    NSError *error = nil;
                    sharedHapticEngine = [[CHHapticEngine alloc] initAndReturnError:&error];
                    if (!error) {
                        __weak typeof(sharedHapticEngine) weakEngine = sharedHapticEngine;
                        sharedHapticEngine.resetHandler = ^{
                            [weakEngine startAndReturnError:nil];
                        };
                    }
                }
            });
            
            if(sharedHapticEngine) {
                NSError *error = nil;
                CHHapticEventParameter *intensityParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:1.0];
                CHHapticEventParameter *sharpnessParam = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.2];
                CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:@[intensityParam, sharpnessParam] relativeTime:0 duration:0.6];
                CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&error];
                if (!error) {
                    [sharedHapticEngine startAndReturnError:nil];
                    id<CHHapticPatternPlayer> player = [sharedHapticEngine createPlayerWithPattern:pattern error:&error];
                    if (!error) {
                        [player startAtTime:0 error:&error];
                    }
                }
            } else {
                // fallback 兜底：重力度Impact反馈
                UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
                [gen prepare];
                [gen impactOccurred];
            }
        }
    }
}
%end