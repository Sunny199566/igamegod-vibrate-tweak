#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

%hook UIView
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    %orig;
    UIWindow *win = self.window;
    if ([NSStringFromClass([win class]) isEqualToString:@"iGameGod.GameGodWindow"]) {
        AudioServicesPlaySystemSound(1519);
    }
}
%end