#import "Runtime.h"
#import "Policy.h"
#import "Catalog.h"
#import "API.h"
#import <AVKit/AVKit.h>
#import <dlfcn.h>

@interface Browser : UIViewController
@property(nonatomic, strong) TVWebView *web;
@property(nonatomic, strong) UIView *input;
@property(nonatomic, strong) UIView *cursor;
@property(nonatomic, strong) UILabel *status;
@property(nonatomic, copy) NSString *lockedHost;
@property(nonatomic) BOOL scrollMode;
@property(nonatomic) BOOL videoRequested;
@property(nonatomic, strong) NSURL *playerURL;
@property(nonatomic) BOOL bootstrapping;
@property(nonatomic, copy) NSString *blockingNotice;
@property(nonatomic, copy) NSString *compatibilityNotice;
- (void)userContentController:(id)controller didReceiveScriptMessage:(id)message;
@end

// WKUserContentController retains its handler, so don't register Browser directly.
@interface TVMessageProxy : NSObject
@property(nonatomic, weak) Browser *target;
@end
@implementation TVMessageProxy
- (void)userContentController:(id)controller didReceiveScriptMessage:(id)message {
    [self.target userContentController:controller didReceiveScriptMessage:message];
}
@end

@implementation Browser
- (BOOL)canBecomeFirstResponder { return YES; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.lockedHost = @"embedse.com";
    self.status = [[UILabel alloc] init];
    self.status.textColor = UIColor.whiteColor;
    self.status.font = [UIFont systemFontOfSize:23];
    self.status.numberOfLines = 2;
    [self.view addSubview:self.status];
    for (NSString *path in @[@"/System/Library/Frameworks/WebKit.framework/WebKit", @"/System/Library/PrivateFrameworks/WebKit.framework/WebKit", @"/System/Library/StagedFrameworks/Safari/WebKit.framework/WebKit"]) {
        if (NSClassFromString(@"WKWebView")) break;
        dlopen(path.UTF8String, RTLD_NOW | RTLD_GLOBAL);
    }
    Class webClass = NSClassFromString(@"WKWebView");
    Class configClass = NSClassFromString(@"WKWebViewConfiguration");
    Class controllerClass = NSClassFromString(@"WKUserContentController");
    Class scriptClass = NSClassFromString(@"WKUserScript");
    if (!webClass || !configClass || !controllerClass || !scriptClass) {
        self.status.text = @"WebKit is unavailable on this tvOS version. This experimental browser cannot run here.";
        return;
    }
    @try {
        TVWebConfiguration *config = [[configClass alloc] init];
        // WebKit disables service workers for ordinary app web views. The
        // provider treats a missing ServiceWorkerContainer as a sandbox error.
        // Use real app-bound support, not a JavaScript service-worker stub.
        if (![config respondsToSelector:@selector(setLimitsNavigationsToAppBoundDomains:)]) {
            self.status.text = @"This tvOS WebKit runtime lacks app-bound player support.";
            return;
        }
        config.limitsNavigationsToAppBoundDomains = YES;
        TVContentController *content = [[controllerClass alloc] init];
        TVMessageProxy *proxy = [[TVMessageProxy alloc] init]; proxy.target = self;
        [content addScriptMessageHandler:proxy name:@"tv"];
        NSString *path = [NSBundle.mainBundle pathForResource:@"Interaction" ofType:@"js"];
        NSString *script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (!script) { self.status.text = @"Missing interaction script. Rebuild the app."; return; }
        script = [script stringByReplacingOccurrencesOfString:@"__CHANNEL__" withString:NSUUID.UUID.UUIDString];
        [content addUserScript:[(TVUserScript *)[scriptClass alloc] initWithSource:script injectionTime:0 forMainFrameOnly:NO]];
        config.userContentController = content;
        if ([config respondsToSelector:@selector(setAllowsInlineMediaPlayback:)]) config.allowsInlineMediaPlayback = YES;
        if ([config respondsToSelector:@selector(setMediaTypesRequiringUserActionForPlayback:)]) config.mediaTypesRequiringUserActionForPlayback = 0;
        self.web = [(TVWebView *)[webClass alloc] initWithFrame:CGRectZero configuration:config];
        self.web.navigationDelegate = self;
        self.web.UIDelegate = self;
        [self.view insertSubview:self.web atIndex:0];
    } @catch (NSException *exception) {
        self.status.text = [@"WebKit initialization failed: " stringByAppendingString:exception.reason ?: @"Unknown runtime error"];
        return;
    }
    // Keep UIKit focus away from web content: the remote operates our cursor.
    self.input = [[UIView alloc] init];
    self.input.backgroundColor = UIColor.clearColor;
    [self.view addSubview:self.input];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    pan.allowedTouchTypes = @[@(UITouchTypeIndirect)];
    [self.input addGestureRecognizer:pan];
    self.cursor = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 22, 22)];
    self.cursor.backgroundColor = UIColor.whiteColor;
    self.cursor.layer.cornerRadius = 11;
    self.cursor.layer.borderWidth = 3;
    self.cursor.layer.borderColor = UIColor.systemBlueColor.CGColor;
    self.cursor.userInteractionEnabled = NO;
    [self.input addSubview:self.cursor];
    [self prepareBlocking];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self becomeFirstResponder];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}
- (void)dealloc { self.web.navigationDelegate = nil; self.web.UIDelegate = nil; }
- (void)prepareBlocking {
    Class store = NSClassFromString(@"WKContentRuleListStore");
    if (!store || ![store respondsToSelector:@selector(defaultStore)]) {
        self.blockingNotice = @"Ad request filter unavailable; popup and navigation guards remain on.";
        [self home]; return;
    }
    NSString *path = [NSBundle.mainBundle pathForResource:@"AdRules" ofType:@"json"];
    NSString *json = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!json) { self.blockingNotice = @"Ad filter resource missing."; [self home]; return; }
    __weak Browser *weakSelf = self;
    [(TVRuleStore *)[store defaultStore] compileContentRuleListForIdentifier:@"tv-ad-rules-v1" encodedContentRuleList:json completionHandler:^(id rules, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            Browser *s = weakSelf; if (!s) return;
            id content = [[s.web valueForKey:@"configuration"] valueForKey:@"userContentController"];
            if (rules && [content respondsToSelector:@selector(addContentRuleList:)]) {
                [content addContentRuleList:rules]; s.blockingNotice = @"Known ad-host filter on";
            } else s.blockingNotice = @"Ad request filter unavailable; popup and navigation guards remain on.";
            [s home];
        });
    }];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    self.status.frame = CGRectMake(50, 20, b.size.width - 100, 76);
    self.web.frame = CGRectMake(0, 110, b.size.width, MAX(1, b.size.height - 110));
    self.input.frame = self.web.frame;
    if (self.cursor.center.x <= 11) self.cursor.center = CGPointMake(b.size.width / 2, self.input.bounds.size.height / 2);
}
- (void)showStatus:(NSString *)message {
    self.status.text = [NSString stringWithFormat:@"%@  •  %@  •  Play/Pause: menu\n%@",
        @"PLAYER LOCKED",
        self.scrollMode ? @"SCROLL" : @"CURSOR", self.compatibilityNotice ?: message ?: @""];
}
- (void)home {
    self.compatibilityNotice = nil;
    if (!TVEmbedURL(self.playerURL.absoluteString)) { [self showStatus:@"Invalid player link. Return to games and retry."]; return; }
    NSString *src = [self.playerURL.absoluteString stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    src = [src stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
    NSString *html = [NSString stringWithFormat:@"<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'><style>html,body{margin:0;width:100%%;height:100%%;background:black}iframe{border:0;width:100%%;height:100%%}</style></head><body><iframe src=\"%@\" allow='autoplay; fullscreen; encrypted-media; picture-in-picture' allowfullscreen referrerpolicy='origin'></iframe></body></html>", src];
    self.bootstrapping = YES;
    [self.web loadHTMLString:html baseURL:[NSURL URLWithString:@"https://tab-lockdown.invalid/"]];
    [self showStatus:self.blockingNotice ?: @"Opening player…"];
}
- (void)act:(NSString *)kind dx:(CGFloat)dx dy:(CGFloat)dy {
    if (!self.web || self.presentedViewController) return;
    CGSize size = self.input.bounds.size;
    if (size.width <= 0 || size.height <= 0) return;
    NSDictionary *action = @{@"kind":kind, @"x":@(self.cursor.center.x / size.width),
        @"y":@(self.cursor.center.y / size.height), @"dx":@(dx), @"dy":@(dy)};
    NSData *json = [NSJSONSerialization dataWithJSONObject:action options:0 error:nil];
    NSString *script = [NSString stringWithFormat:@"window.__tvAct && window.__tvAct(%@)", [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
    [self.web evaluateJavaScript:script completionHandler:^(id value, NSError *error) {
        if (error) [self showStatus:@"Page interaction is unavailable while this page loads."];
    }];
}
- (void)moveX:(CGFloat)x y:(CGFloat)y {
    if (self.scrollMode) { [self act:@"scroll" dx:x dy:y]; return; }
    CGPoint p = self.cursor.center;
    self.cursor.center = CGPointMake(MAX(11, MIN(self.input.bounds.size.width - 11, p.x + x)), MAX(11, MIN(self.input.bounds.size.height - 11, p.y + y)));
}
- (void)pan:(UIPanGestureRecognizer *)pan {
    CGPoint delta = [pan translationInView:self.input];
    [pan setTranslation:CGPointZero inView:self.input];
    [self moveX:delta.x * 1.6 y:delta.y * 1.6];
}
- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (self.presentedViewController) { [super pressesBegan:presses withEvent:event]; return; }
    for (UIPress *press in presses) {
        switch (press.type) {
            case UIPressTypeSelect: [self act:@"click" dx:0 dy:0]; break;
            case UIPressTypeUpArrow: [self moveX:0 y:-45]; break;
            case UIPressTypeDownArrow: [self moveX:0 y:45]; break;
            case UIPressTypeLeftArrow: [self moveX:-45 y:0]; break;
            case UIPressTypeRightArrow: [self moveX:45 y:0]; break;
            case UIPressTypePlayPause: [self menu]; break;
            case UIPressTypeMenu:
                [self.web stopLoading];
                [self.navigationController popViewControllerAnimated:YES];
                break;
            default: [super pressesBegan:[NSSet setWithObject:press] withEvent:event]; break;
        }
    }
}
- (void)menu {
    if (self.presentedViewController) return;
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"Tab Lockdown TV" message:@"Swipe the touch surface to move. Click to select. Switch to Scroll to move the page. TV/Home leaves the app." preferredStyle:UIAlertControllerStyleAlert];
    __weak Browser *weakSelf = self;
    [menu addAction:[UIAlertAction actionWithTitle:self.scrollMode ? @"Use cursor" : @"Use scrolling" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        weakSelf.scrollMode = !weakSelf.scrollMode;
        weakSelf.cursor.backgroundColor = weakSelf.scrollMode ? UIColor.systemOrangeColor : UIColor.whiteColor;
        [weakSelf showStatus:@""];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Back to games" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [weakSelf.web stopLoading]; [weakSelf.navigationController popViewControllerAnimated:YES]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Reload player" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [weakSelf home]; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Open video under cursor in native player" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        // Wait for UIKit's menu dismissal before sending the interaction.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            weakSelf.videoRequested = YES;
            [weakSelf act:@"video" dx:0 dy:0];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ weakSelf.videoRequested = NO; });
        });
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:menu animated:YES completion:nil];
}
// These are the Objective-C WK delegate selectors. No unavailable SDK headers.
- (void)webView:(id)web decidePolicyForNavigationAction:(id)action decisionHandler:(void (^)(NSInteger))decision {
    id frame = [action valueForKey:@"targetFrame"];
    NSURL *url = [[action valueForKey:@"request"] URL];
    BOOL mainFrame = frame && [[frame valueForKey:@"mainFrame"] boolValue];
    // Our local wrapper is the only top-level document, and only native code
    // can bootstrap it. Cross-origin player subframes still need to load.
    BOOL allowed = TVPlayerNavigation(url, frame != nil, mainFrame, self.bootstrapping);
    if ([action respondsToSelector:NSSelectorFromString(@"shouldPerformDownload")] && [[action valueForKey:@"shouldPerformDownload"] boolValue]) allowed = NO;
    decision(allowed ? 1 : 0);
    if (!allowed) [self showStatus:[NSString stringWithFormat:@"Blocked navigation: %@", url.host ?: url.scheme ?: @"popup"]];
}
- (void)webView:(id)web decidePolicyForNavigationResponse:(id)response decisionHandler:(void (^)(NSInteger))decision {
    BOOL main = [[response valueForKey:@"forMainFrame"] boolValue];
    NSURL *url = [[response valueForKey:@"response"] URL];
    BOOL allowed = !main || TVWrapperURL(url);
    decision(allowed ? 1 : 0);
    if (!allowed) [self showStatus:[@"Blocked redirect to " stringByAppendingString:url.host ?: @"unknown host"]];
}
- (id)webView:(id)web createWebViewWithConfiguration:(id)config forNavigationAction:(id)action windowFeatures:(id)features { return nil; }
- (void)webView:(id)web didReceiveServerRedirectForProvisionalNavigation:(id)navigation {
    [self.web stopLoading]; [self showStatus:@"Blocked a redirect away from the player."];
}
- (void)webView:(id)web didFinishNavigation:(id)navigation { self.bootstrapping = NO; [self showStatus:self.blockingNotice]; }
- (void)webView:(id)web didFailProvisionalNavigation:(id)navigation withError:(NSError *)error {
    if (error.code != NSURLErrorCancelled) [self showStatus:error.localizedDescription];
}
- (void)webView:(id)web didFailNavigation:(id)navigation withError:(NSError *)error { [self showStatus:error.localizedDescription]; }
- (void)webViewWebContentProcessDidTerminate:(id)web { [self showStatus:@"Web content stopped. Use Play/Pause → Reload."]; }
- (void)userContentController:(id)controller didReceiveScriptMessage:(id)message {
    id body = [message valueForKey:@"body"];
    if (![body isKindOfClass:NSDictionary.class]) return;
    NSString *kind = body[@"kind"], *value = body[@"value"];
    if (![kind isKindOfClass:NSString.class] || ![value isKindOfClass:NSString.class]) return;
    if ([kind isEqual:@"compatibility"]) {
        id frame = [message valueForKey:@"frameInfo"];
        NSURL *url = [[frame valueForKey:@"request"] URL];
        if (TVEmbedURL(url.absoluteString)) {
            self.compatibilityNotice = [value substringToIndex:MIN(value.length, 240)];
            [self showStatus:self.blockingNotice];
        }
        return;
    }
    if (!self.videoRequested) return;
    self.videoRequested = NO;
    if ([kind isEqual:@"notice"]) { [self showStatus:value]; return; }
    NSURL *url = [NSURL URLWithString:value];
    if (![kind isEqual:@"video"] || !TVAllows(url, nil) || self.presentedViewController) return;
    AVPlayerViewController *player = [[AVPlayerViewController alloc] init];
    player.player = [AVPlayer playerWithURL:url];
    [self presentViewController:player animated:YES completion:^{ [player.player play]; }];
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    Catalog *catalog = [[Catalog alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:catalog];
    __weak UINavigationController *weakNav = nav;
    catalog.openPlayer = ^(NSURL *url, NSString *title) {
        Browser *browser = [[Browser alloc] init]; browser.playerURL = url; browser.title = title;
        [weakNav pushViewController:browser animated:YES];
    };
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
