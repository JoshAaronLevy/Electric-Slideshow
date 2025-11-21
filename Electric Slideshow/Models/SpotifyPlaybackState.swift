import Foundation

/// Current Spotify playback state
struct SpotifyPlaybackState: Codable {
    let isPlaying: Bool
    let item: SpotifyTrack?
    let progressMs: Int?
    
    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case item
        case progressMs = "progress_ms"
    }
}
