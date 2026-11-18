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
        NSURL *wrapper = [NSURL URLWithString:@"https://tab-lockdown.invalid/"];
        NSURL *embed = [NSURL URLWithString:@"https://embedse.com/m/game"];
        NSCAssert(TVPlayerNavigation(wrapper, YES, YES, YES), @"Native wrapper bootstrap allowed");
        NSCAssert(!TVPlayerNavigation(wrapper, YES, YES, NO), @"Page cannot navigate wrapper after bootstrap");
        NSCAssert(!TVPlayerNavigation(embed, YES, YES, YES), @"Embed cannot replace wrapper even during bootstrap");
        NSCAssert(TVPlayerNavigation(embed, YES, NO, NO), @"Embedded player allowed");
        NSCAssert(!TVPlayerNavigation(embed, NO, NO, NO), @"New window blocked");
        NSCAssert(!TVPlayerNavigation([NSURL URLWithString:@"myapp://open"], YES, NO, NO), @"Subframe external app blocked");
        NSCAssert(!TVPlayerNavigation(nil, YES, NO, NO), @"Missing URL blocked");
        NSLog(@"Player wrapper checks passed");
    }
    return 0;
}
