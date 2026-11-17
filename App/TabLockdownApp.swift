import SwiftUI
import AVKit
import WebKit

@main
struct TabLockdownApp: App {
    @StateObject private var browser = BrowserModel()
    var body: some Scene {
        WindowGroup { BrowserScreen(browser: browser) }
    }
}

struct BrowserSurface: UIViewRepresentable {
    let browser: BrowserModel
    func makeUIView(context: Context) -> WKWebView { browser.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct BrowserScreen: View {
    @ObservedObject var browser: BrowserModel
    @State private var input = ""
    @FocusState private var editing: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if browser.hasPage {
                    Button { browser.home(); input = "" } label: { Image(systemName: "house") }
                        .accessibilityLabel("Home")
                }
                TextField("Paste a web or video URL", text: $input)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($editing)
                    .onSubmit { navigate() }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("address")
                Button("Go") { navigate() }.accessibilityIdentifier("go")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            HStack {
                Toggle("Lock hostname", isOn: Binding(get: { browser.locked }, set: { browser.toggleLock($0) }))
                    .font(.subheadline).accessibilityIdentifier("lock-toggle")
                Spacer(minLength: 15)
                Label("Popups blocked", systemImage: "shield.checkered")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal).padding(.bottom, 8)
            if !browser.notice.isEmpty {
                HStack(alignment: .top) {
                    Text(browser.notice).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    Button { browser.notice = "" } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Dismiss message")
                }
                .padding(10).background(Color(.secondarySystemBackground))
            }
            if browser.loading { ProgressView().frame(maxWidth: .infinity).padding(4) }
            if browser.hasPage {
                BrowserSurface(browser: browser)
                HStack {
                    Button { browser.webView.goBack() } label: { Image(systemName: "chevron.left") }
                        .disabled(!browser.canGoBack).accessibilityLabel("Back")
                    Spacer()
                    Button { browser.webView.goForward() } label: { Image(systemName: "chevron.right") }
                        .disabled(!browser.canGoForward).accessibilityLabel("Forward")
                    Spacer()
                    Button { browser.webView.reload() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Reload current page").accessibilityIdentifier("reload")
                    Spacer()
                    Button { browser.bookmark() } label: { Image(systemName: "bookmark.badge.plus") }
                        .accessibilityLabel("Bookmark current page")
                    Spacer()
                    Button { browser.scan() } label: { Label("Video", systemImage: "play.rectangle") }
                        .accessibilityIdentifier("find-video")
                    Spacer()
                    Button { browser.showBookmarks = true } label: { Image(systemName: "book") }
                        .accessibilityLabel("Bookmarks")
                }
                .padding().background(.bar)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "lock.shield.fill").font(.system(size: 40)).foregroundStyle(.green)
                            Text("Tab Lockdown").font(.largeTitle.bold())
                            Text("Browse with popup blocking. Keep navigation on one hostname, or unlock it when you need to change sites.")
                                .foregroundStyle(.secondary)
                            HStack {
                                Button("Open website") { navigate() }.buttonStyle(.borderedProminent)
                                Button("Find video") { editing = false; browser.open(input, scan: true) }.buttonStyle(.bordered)
                            }
                            Button("Save this URL") { browser.bookmark(input) }
                        }
                        Text("Bookmarks").font(.title2.bold())
                        if browser.bookmarks.isEmpty {
                            Text("Save websites here to revisit them.").foregroundStyle(.secondary)
                        }
                        ForEach(browser.bookmarks) { bookmark in
                            Button { input = bookmark.url; navigate() } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title).font(.headline)
                                    Text(bookmark.url).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                        if !browser.bookmarks.isEmpty {
                            Button("Manage bookmarks") { browser.showBookmarks = true }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .tint(Color(red: 0.08, green: 0.40, blue: 0.31))
        .onChange(of: browser.address) { value in if !editing { input = value } }
        .sheet(isPresented: $browser.showMedia) { MediaList(browser: browser) }
        .sheet(isPresented: $browser.showBookmarks) { BookmarkList(browser: browser) }
        .fullScreenCover(item: $browser.playerSession) { session in
            StandalonePlayer(session: session) { browser.playerSession = nil }
        }
    }

    private func navigate() { editing = false; browser.open(input) }
}

struct BookmarkList: View {
    @ObservedObject var browser: BrowserModel
    var body: some View {
        NavigationStack {
            List {
                ForEach(browser.bookmarks) { bookmark in
                    Button { browser.open(bookmark.url); browser.showBookmarks = false } label: {
                        VStack(alignment: .leading) {
                            Text(bookmark.title)
                            Text(bookmark.url).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                }
                .onDelete(perform: browser.removeBookmarks)
            }
            .navigationTitle("Bookmarks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { browser.showBookmarks = false } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
            }
        }
    }
}

struct MediaList: View {
    @ObservedObject var browser: BrowserModel
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Detected on this page and its embedded players. Start the website’s video, then scan again if needed.")
                    Button("Scan current page again") { browser.scan() }
                }
                if browser.media.isEmpty {
                    Text("No media URLs detected yet. Some players use protected or browser-only sources.").foregroundStyle(.secondary)
                }
                ForEach(browser.media) { source in
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Play " + source.kind) { browser.play(source) }
                        Text(source.url.host ?? "").font(.subheadline)
                        Text(source.url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                        ShareLink("Share video URL", item: source.url)
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Text("The standalone player supports iPhone-compatible video files and HLS streams. DRM, DASH, expired links, or sources requiring their original player may need playback on the website.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Videos")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { browser.showMedia = false } } }
        }
    }
}

@MainActor
final class PlayerSession: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL
    let player: AVPlayer
    @Published var error = ""
    private var observation: NSKeyValueObservation?

    init(url: URL, asset: AVURLAsset) {
        self.url = url
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        observation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async {
                self?.error = "This source could not play. Return to its website if it needs the original player or its address has expired."
            }
        }
    }
}

struct NativeVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.showsPlaybackControls = true
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
}

struct StandalonePlayer: View {
    @ObservedObject var session: PlayerSession
    let close: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Done") { session.player.pause(); close() }
                Spacer()
                Button("Go live") {
                    guard let range = session.player.currentItem?.seekableTimeRanges.last?.timeRangeValue else { return }
                    let end = CMTimeGetSeconds(CMTimeRangeGetEnd(range))
                    session.player.seek(to: CMTime(seconds: max(0, end - 2), preferredTimescale: 600))
                }
                Spacer()
                ShareLink(item: session.url) { Image(systemName: "square.and.arrow.up") }
            }
            .padding()
            if !session.error.isEmpty { Text(session.error).font(.caption).padding() }
            NativeVideoPlayer(player: session.player)
        }
        .background(.black).foregroundStyle(.white).tint(.white)
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
            session.player.play()
        }
        .onDisappear { session.player.pause() }
    }
}
