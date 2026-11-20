#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#include <mach/mach_time.h>

typedef struct {
    uint32_t magic;
    uint16_t screenW;
    uint16_t screenH;
    uint8_t  orientation;
    uint8_t  reserved[3];
    uint32_t eventCount;
} GestureHeader;

typedef struct {
    uint8_t type;
    uint8_t fingerId;
    float x;
    float y;
    uint64_t delayNanos;
} TouchEvent;

static NSMutableData *g_recordBuffer = nil;
static uint64_t g_recordStartTime = 0;
static mach_timebase_info_data_t g_timebase;

static uint64_t machTimeToNano(uint64_t machTime) {
    return machTime * g_timebase.numer / g_timebase.denom;
}

static void appendTouchEvent(UITouch *touch, NSNumber *fingerId, CGPoint x, CGPoint y) {
    if(!g_recordBuffer) return;
    uint64_t now = mach_absolute_time();
    uint64_t delay = machTimeToNano(now - g_recordStartTime);

    TouchEvent ev;
    ev.delayNanos = delay;
    ev.fingerId = [fingerId unsignedCharValue];
    ev.x = x.x;
    ev.y = y.y;

    switch(touch.phase) {
        case UITouchPhaseBegan: ev.type = 0; break;
        case UITouchPhaseMoved: ev.type = 1; break;
        case UITouchPhaseEnded:
        case UITouchPhaseCancelled: ev.type = 2; break;
        default: ev.type = 2;
    }
    [g_recordBuffer appendBytes:&ev length:sizeof(TouchEvent)];
}

// ✅ 添加 __attribute__((unused)) 解决未使用函数编译报错
static void __attribute__((unused)) startRecording() {
    if(g_recordBuffer) return;
    mach_timebase_info(&g_timebase);
    g_recordBuffer = [NSMutableData new];
    g_recordStartTime = mach_absolute_time();

    CGSize scrSize = [UIScreen mainScreen].bounds.size;
    uint8_t orient = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation) ? 1 : 0;

    GestureHeader header = {
        .magic = 0x12345678,
        .screenW = (uint16_t)scrSize.width,
        .screenH = (uint16_t)scrSize.height,
        .orientation = orient,
        .eventCount = 0
    };
    [g_recordBuffer appendBytes:&header length:sizeof(GestureHeader)];
}

static void __attribute__((unused)) stopRecordingAndSave() {
    if(!g_recordBuffer) return;
    GestureHeader *hdr = (GestureHeader *)g_recordBuffer.mutableBytes;
    hdr->eventCount = (uint32_t)((g_recordBuffer.length - sizeof(GestureHeader)) / sizeof(TouchEvent));

    NSString *savePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"gesture.bin"];
    [g_recordBuffer writeToFile:savePath atomically:YES];

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:savePath forKey:@"GestureScriptPath"];
    [ud synchronize];

    g_recordBuffer = nil;
}

%hook UIApplication
- (void)sendEvent:(UIEvent *)event {
    %orig;
    if(event.type != UIEventTypeTouches || !g_recordBuffer) return;
    for(UITouch *touch in event.allTouches) {
        CGPoint pt = [touch locationInView:nil];
        NSNumber *fingerId = [touch valueForKey:@"_touchIdentifier"];
        appendTouchEvent(touch, fingerId, pt, pt);
    }
}
%end