#import <UIKit/UIKit.h>

// Local method signatures only. Never link or instantiate these declaration
// classes: actual WebKit classes are resolved dynamically on the device.
@interface TVWebConfiguration : NSObject
@property(nonatomic, strong) id userContentController;
@property(nonatomic) BOOL allowsInlineMediaPlayback;
@property(nonatomic) NSUInteger mediaTypesRequiringUserActionForPlayback;
@property(nonatomic) BOOL limitsNavigationsToAppBoundDomains;
@end
@interface TVContentController : NSObject
- (void)addUserScript:(id)script;
- (void)addScriptMessageHandler:(id)handler name:(NSString *)name;
- (void)addContentRuleList:(id)rules;
@end
@interface TVRuleStore : NSObject
+ (instancetype)defaultStore;
- (void)compileContentRuleListForIdentifier:(NSString *)identifier encodedContentRuleList:(NSString *)json completionHandler:(void (^)(id, NSError *))completion;
@end
@interface TVUserScript : NSObject
- (instancetype)initWithSource:(NSString *)source injectionTime:(NSInteger)time forMainFrameOnly:(BOOL)only;
@end
@interface TVWebView : UIView
- (instancetype)initWithFrame:(CGRect)frame configuration:(id)configuration;
@property(nonatomic, weak) id navigationDelegate;
@property(nonatomic, weak) id UIDelegate;
@property(nonatomic, readonly) NSURL *URL;
@property(nonatomic, readonly) BOOL canGoBack;
- (id)loadRequest:(NSURLRequest *)request;
- (id)loadHTMLString:(NSString *)html baseURL:(NSURL *)url;
- (id)reload;
- (id)goBack;
- (void)stopLoading;
- (void)evaluateJavaScript:(NSString *)script completionHandler:(void (^)(id, NSError *))completion;
@end
