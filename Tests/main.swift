import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
let locked = "example.org"
check(NavigationPolicy.url(from: "example.org/path")?.absoluteString == "https://example.org/path", "Normalize URL")
check(NavigationPolicy.url(from: "javascript:alert(1)") == nil, "Reject script URL")
check(NavigationPolicy.url(from: "https://user:pass@example.org") == nil, "Reject URL credentials")
check(NavigationPolicy.allows(URL(string:"https://example.org/path"), lockedHost:locked), "Allow same host")
check(NavigationPolicy.allows(URL(string:"http://example.org:8080/path"), lockedHost:locked), "Allow changed scheme and port")
check(!NavigationPolicy.allows(URL(string:"https://sub.example.org"), lockedHost:locked), "Reject sibling host")
check(!NavigationPolicy.allows(URL(string:"https://example.org.evil.org"), lockedHost:locked), "Reject hostname suffix")
check(NavigationPolicy.allows(URL(string:"https://other.org"), lockedHost:nil), "Unlocked navigation")
check(!NavigationPolicy.allows(URL(string:"customapp://example.org"), lockedHost:nil), "No external apps")
check(NavigationPolicy.mediaKind(URL(string:"https://cdn.org/live.m3u8?token=abc")!) == "HLS", "Signed HLS")
check(NavigationPolicy.mediaKind(URL(string:"https://cdn.org/stream?id=1")!, mime:"application/vnd.apple.mpegurl") == "HLS", "MIME detection")
print("Passed navigation and media policy checks")
