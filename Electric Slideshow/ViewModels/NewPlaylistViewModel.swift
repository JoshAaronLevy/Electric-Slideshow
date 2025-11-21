import Foundation

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
        
        return AppPlaylist(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            trackURIs: Array(selectedTrackURIs)
        )
    }
    
    func reset() {
        name = ""
        selectedTrackURIs.removeAll()
        errorMessage = nil
    }
}
