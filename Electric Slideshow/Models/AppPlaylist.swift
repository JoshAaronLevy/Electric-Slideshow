import Foundation

/// App-local playlist that references Spotify tracks by URI
/// Stored locally, NOT synced to user's Spotify account
struct AppPlaylist: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var trackURIs: [String]  // Spotify track URIs (e.g., "spotify:track:...")
    var playlistDefaultClipMode: MusicClipMode?
    let createdAt: Date
    var updatedAt: Date
    
    // Computed
    var trackCount: Int {
        trackURIs.count
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        trackURIs: [String],
        playlistDefaultClipMode: MusicClipMode? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.trackURIs = trackURIs
        self.playlistDefaultClipMode = playlistDefaultClipMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
