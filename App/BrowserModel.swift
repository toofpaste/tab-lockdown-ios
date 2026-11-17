import SwiftUI
import WebKit
import AVKit

@MainActor
final class MediaBridge: NSObject, WKScriptMessageHandler {
    weak var owner: BrowserModel?
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.receive(message)
    }
}

@MainActor
final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var address = ""
    @Published var title = "Tab Lockdown"
    @Published var hasPage = false
    @Published var loading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var locked = true
    @Published var lockedHost: String?
    @Published var notice = ""
    @Published var media: [MediaSource] = []
    @Published var bookmarks: [Bookmark] = []
    @Published var showMedia = false
    @Published var showBookmarks = false
    @Published var playerSession: PlayerSession?

    let webView: WKWebView
    private let bridge = MediaBridge()
    private var observations: [NSKeyValueObservation] = []
    private var lastAllowed: URL?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        bridge.owner = self
        configuration.userContentController.add(bridge, name: "media")
        if let scriptURL = Bundle.main.url(forResource: "MediaDiscovery", withExtension: "js"),
           let script = try? String(contentsOf: scriptURL) {
            configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        if let data = UserDefaults.standard.data(forKey: "bookmarks"),
           let saved = try? JSONDecoder().decode([Bookmark].self, from: data) { bookmarks = saved }
        observations = [
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.updateLocation() }
            },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.title = self?.webView.title ?? "Tab Lockdown" }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.loading = self?.webView.isLoading ?? false }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.canGoBack = self?.webView.canGoBack ?? false }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.canGoForward = self?.webView.canGoForward ?? false }
            }
        ]
    }

    func open(_ input: String, scan: Bool = false) {
        guard let url = NavigationPolicy.url(from: input) else {
            notice = "Enter an HTTP or HTTPS web address."
            return
        }
        if scan, let kind = NavigationPolicy.mediaKind(url) {
            media = [MediaSource(url: url, kind: kind)]
            showMedia = true
            return
        }
        notice = ""
        media.removeAll()
        address = url.absoluteString
        lockedHost = locked ? url.host?.lowercased() : nil
        lastAllowed = url
        hasPage = true
        showBookmarks = false
        webView.load(URLRequest(url: url))
        if scan { showMedia = true }
    }

    func toggleLock(_ enabled: Bool) {
        locked = enabled
        lockedHost = enabled ? webView.url?.host?.lowercased() : nil
        notice = enabled ? "Hostname lockdown enabled." : "Hostname lockdown off. Popups remain blocked."
    }

    func scan() {
        notice = ""
        showMedia = true
        webView.evaluateJavaScript("window.postMessage('__tabLockdownScanFrames','*');", completionHandler: nil)
    }

    func receive(_ message: WKScriptMessage) {
        guard hasPage, message.name == "media",
              let data = message.body as? [String: Any],
              let value = data["url"] as? String, value.count <= 16000,
              let url = NavigationPolicy.url(from: value),
              let kind = NavigationPolicy.mediaKind(url, mime: data["type"] as? String ?? ""),
              media.count < 150, !media.contains(where: { $0.url == url }) else { return }
        media.append(MediaSource(url: url, kind: kind))
    }

    func updateLocation() {
        guard hasPage, let url = webView.url, ["http", "https"].contains(url.scheme ?? "") else { return }
        address = url.absoluteString
        if NavigationPolicy.allows(url, lockedHost: locked ? lockedHost : nil) { lastAllowed = url }
    }

    func bookmark(_ input: String? = nil) {
        guard let url = NavigationPolicy.url(from: input ?? address) else { notice = "Enter a web address to save."; return }
        guard !bookmarks.contains(where: { $0.url == url.absoluteString }) else { notice = "Already bookmarked."; return }
        bookmarks.append(Bookmark(url: url.absoluteString, title: webView.url == url ? title : url.host ?? url.absoluteString))
        saveBookmarks()
        notice = "Bookmark saved."
    }

    func removeBookmarks(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        saveBookmarks()
    }

    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) { UserDefaults.standard.set(data, forKey: "bookmarks") }
    }

    func home() {
        hasPage = false
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        address = ""
        media.removeAll()
        lockedHost = nil
        notice = ""
    }

    func play(_ source: MediaSource) {
        guard source.kind != "DASH" else {
            notice = "This source uses DASH. Play it in the website’s own player.";
            showMedia = false
            return
        }
        webView.evaluateJavaScript("window.postMessage('__tabLockdownPauseFrames','*');", completionHandler: nil)
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            DispatchQueue.main.async {
                let asset = AVURLAsset(url: source.url, options: [AVURLAssetHTTPCookiesKey: cookies])
                self?.playerSession = PlayerSession(url: source.url, asset: asset)
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let frame = navigationAction.targetFrame else {
            notice = "Popup blocked."
            decisionHandler(.cancel)
            return
        }
        if !hasPage && navigationAction.request.url?.absoluteString == "about:blank" {
            decisionHandler(.allow)
            return
        }
        if frame.isMainFrame && !NavigationPolicy.allows(navigationAction.request.url, lockedHost: locked ? lockedHost : nil) {
            notice = "Navigation blocked. Turn off hostname lockdown to change sites."
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame && hasPage &&
            !NavigationPolicy.allows(navigationResponse.response.url, lockedHost: locked ? lockedHost : nil) {
            notice = "Off-site redirect blocked."
            decisionHandler(.cancel)
            return
        }
        if let url = navigationResponse.response.url,
           let kind = NavigationPolicy.mediaKind(url, mime: navigationResponse.response.mimeType ?? ""),
           !media.contains(where: { $0.url == url }) {
            media.append(MediaSource(url: url, kind: kind))
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        if locked, hasPage, !NavigationPolicy.allows(webView.url, lockedHost: lockedHost) {
            webView.stopLoading()
            notice = "Off-site redirect blocked."
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if locked, hasPage, !NavigationPolicy.allows(webView.url, lockedHost: lockedHost), let url = lastAllowed {
            webView.stopLoading()
            webView.load(URLRequest(url: url))
            notice = "Returned to the locked hostname."
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        media.removeAll()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateLocation()
        webView.evaluateJavaScript("window.postMessage('__tabLockdownScanFrames','*');", completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { notice = error.localizedDescription }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { notice = error.localizedDescription }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        notice = "The page stopped. Tap Reload to reopen it."
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        notice = "Popup blocked."
        return nil
    }
}
