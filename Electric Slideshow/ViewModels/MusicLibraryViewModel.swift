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
    private var hasLoaded = false
    
    init(apiService: SpotifyAPIService) {
        self.apiService = apiService
    }
    
    func loadLibrary() async {
        // Prevent duplicate loads
        guard !isLoading else {
            print("[MusicLibraryVM] Already loading, skipping duplicate request")
            return
        }
        
        // If already loaded successfully, skip
        if hasLoaded && !spotifyPlaylists.isEmpty && !savedTracks.isEmpty {
            print("[MusicLibraryVM] Library already loaded, skipping")
            return
        }
        
        isLoading = true
        errorMessage = nil
        print("[MusicLibraryVM] Starting to load Spotify library...")
        
        do {
            // Load sequentially to avoid URLSession cancellation issues
            print("[MusicLibraryVM] Fetching playlists...")
            spotifyPlaylists = try await apiService.fetchUserPlaylists()
            print("[MusicLibraryVM] Fetched \(spotifyPlaylists.count) playlists")
            
            print("[MusicLibraryVM] Fetching saved tracks...")
            savedTracks = try await apiService.fetchSavedTracks()
            print("[MusicLibraryVM] Fetched \(savedTracks.count) tracks")
            
            hasLoaded = true
            isLoading = false
            print("[MusicLibraryVM] Successfully loaded library")
        } catch {
            errorMessage = "Failed to load Spotify library: \(error.localizedDescription)"
            print("[MusicLibraryVM] ERROR: \(error)")
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
