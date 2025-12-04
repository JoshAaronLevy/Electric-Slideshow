import Foundation

/// Per-track settings and optional cached metadata for playlists.
struct PlaylistTrack: Identifiable, Codable, Equatable {
    enum ClipMode: String, Codable, Equatable {
        case `default`
        case custom
    }
    
    /// Spotify track URI (e.g., "spotify:track:...")
    let uri: String
    
    /// Whether this track uses default clipping (playlist/global) or a custom range.
    var clipMode: ClipMode
    
    /// Custom start/end positions in milliseconds. Only used when `clipMode == .custom`.
    var customStartMs: Int?
    var customEndMs: Int?
    
    // Optional cached metadata
    var name: String?
    var artist: String?
    var album: String?
    var durationMs: Int?
    var albumArtURL: URL?
    var fetchedAt: Date?
    
    var id: String { uri }
    
    init(
        uri: String,
        clipMode: ClipMode = .default,
        customStartMs: Int? = nil,
        customEndMs: Int? = nil,
        name: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        durationMs: Int? = nil,
        albumArtURL: URL? = nil,
        fetchedAt: Date? = nil
    ) {
        self.uri = uri
        self.clipMode = clipMode
        self.customStartMs = customStartMs
        self.customEndMs = customEndMs
        self.name = name
        self.artist = artist
        self.album = album
        self.durationMs = durationMs
        self.albumArtURL = albumArtURL
        self.fetchedAt = fetchedAt
    }
}
