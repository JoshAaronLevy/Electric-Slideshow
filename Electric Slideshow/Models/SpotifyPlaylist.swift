import Foundation

/// Spotify playlist from user's library
struct SpotifyPlaylist: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let tracks: TracksInfo
    let images: [SpotifyImage]
    
    struct TracksInfo: Codable {
        let total: Int
    }
    
    var imageURL: URL? {
        images.first?.url
    }
}

/// Response wrapper for Spotify playlists endpoint
struct SpotifyPlaylistsResponse: Codable {
    let items: [SpotifyPlaylist]
}
