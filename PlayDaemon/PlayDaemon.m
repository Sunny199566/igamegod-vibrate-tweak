#import <Foundation/Foundation.h>

@protocol GestureDaemonProtocol
- (void)startRecord;
- (void)stopRecord;
- (void)playGesture;
@end

@interface DaemonHandler : NSObject <NSXPCListenerDelegate, GestureDaemonProtocol>
@end

@implementation DaemonHandler

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(GestureDaemonProtocol)];
    newConnection.exportedObject = self;
    [newConnection resume];
    return YES;
}

- (void)startRecord {
    NSLog(@"[Daemon] ✅ 收到指令：开始录制手势");
    // ========== 这里放你的触摸采集底层录制代码 ==========
}
- (void)stopRecord {
    NSLog(@"[Daemon] ✅ 收到指令：停止录制手势");
    // ========== 这里放停止录制底层代码 ==========
}
- (void)playGesture {
    NSLog(@"[Daemon] ✅ 收到指令：回放手势");
    // ========== 这里放触摸回放底层模拟代码 ==========
}
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        DaemonHandler *handler = [[DaemonHandler alloc] init];
        NSXPCListener *listener = [[NSXPCListener alloc] initWithMachServiceName:@"com.globalgesture.gesturemanager.xpc"];
        listener.delegate = handler;
        [listener resume];
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}