import Foundation

enum NavigationPolicy {
    static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: candidate),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    static func allows(_ url: URL?, lockedHost: String?) -> Bool {
        guard let url = url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host else { return false }
        return lockedHost == nil || host.lowercased() == lockedHost?.lowercased()
    }

    static func mediaKind(_ url: URL, mime: String = "") -> String? {
        let type = mime.lowercased()
        if url.pathExtension.lowercased() == "m3u8" || type.contains("mpegurl") { return "HLS" }
        if url.pathExtension.lowercased() == "mpd" || type.contains("dash+xml") { return "DASH" }
        if ["mp4", "m4v", "mov", "webm", "ogv"].contains(url.pathExtension.lowercased()) || type.hasPrefix("video/") { return "Video" }
        return nil
    }
}

struct Bookmark: Codable, Identifiable {
    var id: String { url }
    let url: String
    let title: String
}

struct MediaSource: Identifiable {
    var id: String { url.absoluteString }
    let url: URL
    let kind: String
}
