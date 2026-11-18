#import <Foundation/Foundation.h>
static NSString * const TVHome = @"https://v2.streameast.ph/";
static inline BOOL TVAllows(NSURL *url, NSString *host) {
    return url && ([@"https" isEqual:url.scheme.lowercaseString] || [@"http" isEqual:url.scheme.lowercaseString])
        && url.host.length && (!host || [url.host.lowercaseString isEqual:host.lowercaseString]);
}
