#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

%hook UIGestureRecognizer
- (void)setState:(UIGestureRecognizerState)state {
    %orig;
    // 手势识别成功（结束）
    if(state == UIGestureRecognizerStateRecognized) {
        UIView *targetView = self.view;
        if(targetView) {
            UIWindow *win = targetView.window;
            if ([NSStringFromClass([win class]) isEqualToString:@"iGameGod.GameGodWindow"]) {
                AudioServicesPlaySystemSound(1519);
            }
        }
    }
}
%end