#import "../App/API.h"
int main(void) {
    @autoreleasepool {
        NSCAssert(TVEmbedURL(@"https://embedse.com/m/Ab_12/2?source=bravo"), @"Valid server URL");
        for (id value in @[[NSNull null], @42, @"", @"https://evil.example/m/id", @"https://embedse.com.evil.example/m/id", @"https://user@embedse.com/m/id", @"http://embedse.com/m/id", @"https://embedse.com/ads", @"https://embedse.com:444/m/id"]) NSCAssert(!TVEmbedURL(value), @"Reject untrusted URL %@", value);
        NSCAssert(!TVRows(@{@"ok":@NO,@"matches":@[]}, @"matches"), @"API error rejected");
        NSCAssert(!TVRows(@{@"ok":@YES,@"matches":NSNull.null}, @"matches"), @"Malformed collection rejected");
        NSCAssert(TVRows(@{@"ok":@YES,@"matches":@[@{@"id":@"abc",@"sport":NSNull.null},NSNull.null,@{@"id":@42}]}, @"matches").count == 1, @"Nullable sport is valid; invalid rows dropped");
        NSLog(@"API schema and embed URL checks passed");
    }
    return 0;
}
