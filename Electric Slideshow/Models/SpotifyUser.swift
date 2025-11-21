import Foundation

/// Spotify user profile information
struct SpotifyUser: Codable {
    let id: String
    let displayName: String?
    let email: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
    }
}
