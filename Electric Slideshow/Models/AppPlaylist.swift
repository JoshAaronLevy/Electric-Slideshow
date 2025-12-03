import Foundation

/// App-local playlist that references Spotify tracks by URI
/// Stored locally, NOT synced to user's Spotify account
struct AppPlaylist: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var playlistTracks: [PlaylistTrack]
    var playlistDefaultClipMode: MusicClipMode?
    let createdAt: Date
    var updatedAt: Date
    
    // Computed
    var trackURIs: [String] {
        playlistTracks.map { $0.uri }
    }
    
    var trackCount: Int {
        playlistTracks.count
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        playlistTracks: [PlaylistTrack],
        playlistDefaultClipMode: MusicClipMode? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.playlistTracks = playlistTracks
        self.playlistDefaultClipMode = playlistDefaultClipMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Codable (migration-friendly)
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case playlistTracks
        case playlistDefaultClipMode
        case trackURIs // legacy key for migration
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.playlistDefaultClipMode = try container.decodeIfPresent(MusicClipMode.self, forKey: .playlistDefaultClipMode)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        
        if let tracks = try container.decodeIfPresent([PlaylistTrack].self, forKey: .playlistTracks) {
            self.playlistTracks = tracks
        } else if let uris = try container.decodeIfPresent([String].self, forKey: .trackURIs) {
            // Legacy migration: map URIs to default playlist tracks
            self.playlistTracks = uris.map { PlaylistTrack(uri: $0) }
        } else {
            self.playlistTracks = []
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(playlistTracks, forKey: .playlistTracks)
        try container.encodeIfPresent(playlistDefaultClipMode, forKey: .playlistDefaultClipMode)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        
        // Encode legacy trackURIs for backward compatibility
        try container.encode(trackURIs, forKey: .trackURIs)
    }
}
