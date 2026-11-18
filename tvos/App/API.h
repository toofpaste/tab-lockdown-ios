#import <Foundation/Foundation.h>
static inline NSString *TVString(id value) { return [value isKindOfClass:NSString.class] ? value : @""; }
static inline NSURL *TVEmbedURL(id value) {
    NSString *text = TVString(value);
    NSURL *url = [NSURL URLWithString:text];
    if (![url.scheme.lowercaseString isEqual:@"https"] || ![url.host.lowercaseString isEqual:@"embedse.com"] || url.user || url.password || (url.port && url.port.integerValue != 443)) return nil;
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"^/m/[A-Za-z0-9_-]+(?:/[0-9]+)?$" options:0 error:nil];
    return [pattern numberOfMatchesInString:url.path options:0 range:NSMakeRange(0, url.path.length)] == 1 ? url : nil;
}
// Drop malformed entries without losing otherwise valid games/servers.
static inline NSArray<NSDictionary *> *TVRows(id object, NSString *key) {
    if (![object isKindOfClass:NSDictionary.class] || ![object[@"ok"] isEqual:@YES] || ![object[key] isKindOfClass:NSArray.class]) return nil;
    NSMutableArray *rows = [NSMutableArray array];
    for (id row in object[key]) if ([row isKindOfClass:NSDictionary.class] && TVString(row[@"id"]).length) [rows addObject:row];
    return rows;
}
@interface TVAPI : NSObject
- (void)fetch:(NSString *)path completion:(void (^)(NSDictionary *, NSString *))completion;
@end
