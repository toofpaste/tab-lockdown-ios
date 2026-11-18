#import "../App/Policy.h"
int main(void) {
    @autoreleasepool {
        NSString *host = @"v2.streameast.ph";
        NSCAssert(TVAllows([NSURL URLWithString:TVHome], host), @"Home allowed");
        NSCAssert(TVAllows([NSURL URLWithString:@"http://v2.streameast.ph:8080/match"], host), @"Same host allowed");
        NSCAssert(!TVAllows([NSURL URLWithString:@"https://auth.streamea.st/"], host), @"SSO requires unlock");
        NSCAssert(!TVAllows([NSURL URLWithString:@"https://v2.streameast.ph.evil.example/"], host), @"Suffix rejected");
        NSCAssert(!TVAllows([NSURL URLWithString:@"https://v2.streameast.ph@evil.example/"], host), @"Userinfo rejected");
        NSCAssert(!TVAllows([NSURL URLWithString:@"javascript:alert(1)"], nil), @"External schemes rejected");
        NSCAssert(!TVAllows(nil, nil), @"Missing URL rejected");
        NSCAssert(TVAllows([NSURL URLWithString:@"https://auth.streamea.st/"], nil), @"Unlock allows SSO");
        NSLog(@"Navigation policy checks passed");
    }
    return 0;
}
