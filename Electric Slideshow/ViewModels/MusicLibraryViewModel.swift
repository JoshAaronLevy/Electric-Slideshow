import Foundation
import Combine

/// ViewModel for browsing Spotify library and selecting tracks
@MainActor
final class MusicLibraryViewModel: ObservableObject {
    @Published var spotifyPlaylists: [SpotifyPlaylist] = []
    @Published var savedTracks: [SpotifyTrack] = []
    @Published var selectedTrackURIs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService: SpotifyAPIService
    
    init(apiService: SpotifyAPIService) {
        self.apiService = apiService
    }
    
    func loadLibrary() async {
        isLoading = true
        errorMessage = nil
        
        async let playlistsResult = apiService.fetchUserPlaylists()
        async let tracksResult = apiService.fetchSavedTracks()
        
        do {
            spotifyPlaylists = try await playlistsResult
            savedTracks = try await tracksResult
            isLoading = false
        } catch {
            errorMessage = "Failed to load Spotify library"
            isLoading = false
        }
    }
    
    func toggleTrack(_ uri: String) {
        if selectedTrackURIs.contains(uri) {
            selectedTrackURIs.remove(uri)
        } else {
            selectedTrackURIs.insert(uri)
        }
    }
    
    func clearSelection() {
        selectedTrackURIs.removeAll()
    }
}
