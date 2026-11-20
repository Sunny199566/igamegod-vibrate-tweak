#import <UIKit/UIKit.h>

@protocol GestureDaemonProtocol
- (void)startRecord;
- (void)stopRecord;
- (void)playGesture;
@end

@interface MainViewController : UIViewController
@property (nonatomic, strong) UIButton *recordBtn;
@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UIButton *stopBtn;
@property (nonatomic, strong) NSXPCConnection *connection;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // XPC连接初始化
    self.connection = [[NSXPCConnection alloc] initWithMachServiceName:@"com.globalgesture.gesturemanager.xpc"];
    self.connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(GestureDaemonProtocol)];
    [self.connection resume];
    
    CGFloat btnWidth = 220;
    CGFloat btnHeight = 50;
    CGFloat yOffset = self.view.bounds.size.height / 2 - 120;
    
    self.recordBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.recordBtn.frame = CGRectMake((self.view.bounds.size.width - btnWidth)/2, yOffset, btnWidth, btnHeight);
    [self.recordBtn setTitle:@"开始录制手势" forState:UIControlStateNormal];
    self.recordBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.recordBtn.backgroundColor = [UIColor systemBlueColor];
    [self.recordBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.recordBtn.layer.cornerRadius = 12;
    [self.recordBtn addTarget:self action:@selector(startRecordAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.recordBtn];
    
    self.playBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playBtn.frame = CGRectMake((self.view.bounds.size.width - btnWidth)/2, yOffset + 70, btnWidth, btnHeight);
    [self.playBtn setTitle:@"回放手势" forState:UIControlStateNormal];
    self.playBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.playBtn.backgroundColor = [UIColor systemGreenColor];
    [self.playBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.playBtn.layer.cornerRadius = 12;
    [self.playBtn addTarget:self action:@selector(playAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.playBtn];
    
    self.stopBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.stopBtn.frame = CGRectMake((self.view.bounds.size.width - btnWidth)/2, yOffset + 140, btnWidth, btnHeight);
    [self.stopBtn setTitle:@"停止全部" forState:UIControlStateNormal];
    self.stopBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.stopBtn.backgroundColor = [UIColor systemRedColor];
    [self.stopBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.stopBtn.layer.cornerRadius = 12;
    [self.stopBtn addTarget:self action:@selector(stopAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.stopBtn];
}

- (void)startRecordAction:(id)sender {
    id<GestureDaemonProtocol> proxy = [self.connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:@"Daemon守护进程未启动，请重启设备！" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
    [proxy startRecord];
}

- (void)playAction:(id)sender {
    id<GestureDaemonProtocol> proxy = [self.connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:@"Daemon守护进程未启动，请重启设备！" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
    [proxy playGesture];
}

- (void)stopAction:(id)sender {
    id<GestureDaemonProtocol> proxy = [self.connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:@"Daemon守护进程未启动，请重启设备！" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
    [proxy stopRecord];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    MainViewController *rootVC = [[MainViewController alloc] init];
    self.window.rootViewController = rootVC;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}