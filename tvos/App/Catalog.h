#import <UIKit/UIKit.h>
@interface Catalog : UITableViewController
@property(nonatomic, copy) void (^openWebsite)(void);
@property(nonatomic, copy) void (^openPlayer)(NSURL *url, NSString *title);
@end
