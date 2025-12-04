import Foundation
import Combine

/// ViewModel for managing Spotify connection state
@MainActor
final class MusicViewModel: ObservableObject {
    @Published var isConnecting = false
    
    private let spotifyAuthService: SpotifyAuthService
    
    init(spotifyAuthService: SpotifyAuthService = .shared) {
        self.spotifyAuthService = spotifyAuthService
    }
    
    var isConnected: Bool {
        spotifyAuthService.isAuthenticated
    }
    
    var statusMessage: String {
        if isConnected {
            return "Connected to Spotify"
        } else {
            return "Not connected to Spotify"
        }
    }
    
    func connectToSpotify() {
        isConnecting = true
        spotifyAuthService.beginAuthentication()
        
        // Reset connecting state after a delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            isConnecting = false
        }
    }
    
    func disconnectFromSpotify() {
        spotifyAuthService.signOut()
    }
}
