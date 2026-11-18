#import "API.h"
@interface TVAPI ()
@property(nonatomic, strong) NSMutableDictionary *cache;
@property(nonatomic, strong) NSDate *retryAt;
@end
@implementation TVAPI
- (instancetype)init { if ((self = [super init])) _cache = [NSMutableDictionary dictionary]; return self; }
- (void)fetch:(NSString *)path completion:(void (^)(NSDictionary *, NSString *))completion {
    // All callers run on main. Cache state is updated only on main too.
    NSDictionary *cached = self.cache[path];
    if ([self.retryAt timeIntervalSinceNow] > 0) { completion(nil, @"API rate limit reached. Please wait a minute before retrying."); return; }
    if (cached && -[cached[@"date"] timeIntervalSinceNow] < 30) { completion(cached[@"body"], nil); return; }
    NSURL *url = [NSURL URLWithString:[@"https://api.embedse.com/v1/" stringByAppendingString:path]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    if (cached[@"etag"]) [request setValue:cached[@"etag"] forHTTPHeaderField:@"If-None-Match"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (id)response : nil;
        id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { completion(nil, error.localizedDescription); return; }
            if (http.statusCode == 429) {
                NSString *header = [http valueForHTTPHeaderField:@"Retry-After"];
                NSTimeInterval delay = header.doubleValue;
                if (delay <= 0) {
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                    formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss zzz";
                    delay = [[formatter dateFromString:header] timeIntervalSinceNow];
                }
                self.retryAt = [NSDate dateWithTimeIntervalSinceNow:MAX(60, delay)];
                completion(nil, @"API rate limit reached. Please wait before retrying."); return;
            }
            if (http.statusCode == 304 && cached) {
                NSMutableDictionary *fresh = [cached mutableCopy]; fresh[@"date"] = NSDate.date;
                self.cache[path] = fresh; completion(cached[@"body"], nil); return;
            }
            if (http.statusCode != 200 || ![json isKindOfClass:NSDictionary.class] || ![json[@"ok"] isEqual:@YES]) {
                completion(nil, http.statusCode == 503 ? @"The provider's game data is temporarily unavailable. Try again shortly." : [NSString stringWithFormat:@"Could not load games (HTTP %ld).", (long)http.statusCode]); return;
            }
            NSMutableDictionary *entry = [@{@"body":json, @"date":NSDate.date} mutableCopy];
            NSString *etag = [http valueForHTTPHeaderField:@"ETag"]; if (etag) entry[@"etag"] = etag;
            self.cache[path] = entry;
            completion(json, nil);
        });
    }] resume];
}
@end
