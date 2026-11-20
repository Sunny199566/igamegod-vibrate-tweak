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
    }
}

%hook UIGestureRecognizer
- (void)setState:(UIGestureRecognizerState)state {
    %orig;
    if(state == UIGestureRecognizerStateRecognized) {
        // 过滤拖拽、长按
        if ([self isKindOfClass:objc_getClass("UIPanGestureRecognizer")] ||
            [self isKindOfClass:objc_getClass("UILongPressGestureRecognizer")]) {
            return;
        }
        UIView *targetView = self.view;
        if(!targetView) return;
        UIViewController *vc = nil;
        UIResponder *resp = targetView;
        // 沿着响应链向上查找ViewController
        while(resp) {
            if ([resp isKindOfClass:[UIViewController class]]) {
                vc = (UIViewController *)resp;
                break;
            }
            resp = resp.nextResponder;
        }
        if (!vc) return;
        
        // ✅ 判断控制器类名 iGameGod.ToolKitViewController，这个是固定不变的
        if (![NSStringFromClass([vc class]) isEqualToString:@"iGameGod.ToolKitViewController"]) {
            return;
        }
        
        SetupHapticEngine();
        PlayCustomHaptic();
    }
}
%end

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        SetupHapticEngine();
    });
}