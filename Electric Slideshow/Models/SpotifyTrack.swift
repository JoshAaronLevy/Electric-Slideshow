import Foundation

/// Spotify track with metadata
struct SpotifyTrack: Codable, Identifiable {
    let id: String
    let name: String
    let uri: String
    let durationMs: Int
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    
    enum CodingKeys: String, CodingKey {
        case id, name, uri, artists, album
        case durationMs = "duration_ms"
    }
    
    var artistNames: String {
        artists.map { $0.name }.joined(separator: ", ")
    }
}

/// Spotify artist information
struct SpotifyArtist: Codable {
    let id: String
    let name: String
}

/// Spotify album information
struct SpotifyAlbum: Codable {
    let id: String
    let name: String
    let images: [SpotifyImage]
    
    var imageURL: URL? {
        images.first?.url
    }
}

/// Spotify image with dimensions
struct SpotifyImage: Codable {
    let url: URL
    let height: Int?
    let width: Int?
}

/// Response wrapper for playlist tracks endpoint
struct SpotifyTracksResponse: Codable {
    let items: [TrackItem]
    
    struct TrackItem: Codable {
        let track: SpotifyTrack
    }
}

/// Response wrapper for saved tracks endpoint
struct SpotifySavedTracksResponse: Codable {
    let items: [SavedTrackItem]
    
    struct SavedTrackItem: Codable {
        let track: SpotifyTrack
    }
}

/// Response wrapper for the `/tracks` batch lookup endpoint
struct SpotifyTracksListResponse: Codable {
    let tracks: [SpotifyTrack]
}
