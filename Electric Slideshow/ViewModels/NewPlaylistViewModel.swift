import Foundation
import Combine

/// ViewModel for creating new app playlists
@MainActor
final class NewPlaylistViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var selectedTrackURIs: Set<String> = []
    @Published var errorMessage: String?
    
    private let playlistsStore: PlaylistsStore
    
    init(playlistsStore: PlaylistsStore) {
        self.playlistsStore = playlistsStore
    }
    
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedTrackURIs.isEmpty
    }
    
    func buildPlaylist() -> AppPlaylist? {
        guard canSave else { return nil }
        
        let tracks = selectedTrackURIs.map { uri in
            PlaylistTrack(uri: uri)
        }
        
        return AppPlaylist(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            playlistTracks: tracks.sorted { $0.uri < $1.uri }
        )
    }
    
    func reset() {
        name = ""
        selectedTrackURIs.removeAll()
        errorMessage = nil
    }
}
