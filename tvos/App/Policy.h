#import <Foundation/Foundation.h>
static NSString * const TVHome = @"https://v2.streameast.ph/";
static inline BOOL TVAllows(NSURL *url, NSString *host) {
    return url && ([@"https" isEqual:url.scheme.lowercaseString] || [@"http" isEqual:url.scheme.lowercaseString])
        && url.host.length && (!host || [url.host.lowercaseString isEqual:host.lowercaseString]);
}
static inline BOOL TVWrapperURL(NSURL *url) {
    return [url.absoluteString isEqual:@"about:blank"] || [url.absoluteString isEqual:@"https://tab-lockdown.invalid/"];
}
static inline BOOL TVPlayerNavigation(NSURL *url, BOOL hasTarget, BOOL mainFrame, BOOL bootstrapping) {
    if (!hasTarget || !url) return NO;
    if (mainFrame) return bootstrapping && TVWrapperURL(url);
    return [@[@"http", @"https", @"about", @"blob", @"data"] containsObject:url.scheme.lowercaseString ?: @""];
}
