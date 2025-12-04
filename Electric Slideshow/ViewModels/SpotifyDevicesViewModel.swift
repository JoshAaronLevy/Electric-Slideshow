import Foundation
import Combine

@MainActor
final class SpotifyDevicesViewModel: ObservableObject {
    @Published var devices: [SpotifyDevice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let apiService: SpotifyAPIService
    
    init(apiService: SpotifyAPIService) {
        self.apiService = apiService
    }
    
    /// Convenience initializer for previews / simple wiring
    convenience init() {
        let authService = SpotifyAuthService.shared
        let apiService = SpotifyAPIService(authService: authService)
        self.init(apiService: apiService)
    }
    
    func loadDevices() async {
        print("[SpotifyDevicesVM] Starting loadDevices()")
        isLoading = true
        errorMessage = nil
        
        defer {
            print("[SpotifyDevicesVM] loadDevices() completed, setting isLoading = false")
            isLoading = false
        }
        
        do {
            print("[SpotifyDevicesVM] Calling apiService.fetchAvailableDevices()...")
            let fetchedDevices = try await apiService.fetchAvailableDevices()
            print("[SpotifyDevicesVM] Successfully fetched \(fetchedDevices.count) devices")
            self.devices = fetchedDevices
            
            // Provide user-friendly feedback for empty device list
            if fetchedDevices.isEmpty {
                self.errorMessage = "No Spotify devices found. Make sure Spotify is open on at least one device."
            }
            
        } catch {
            print("[SpotifyDevicesVM] ERROR: Failed to fetch devices: \(error)")
            print("[SpotifyDevicesVM] ERROR: Localized description: \(error.localizedDescription)")
            self.devices = []
            
            // Enhanced error handling with user-friendly messages
            let errorMessage = self.getUserFriendlyErrorMessage(for: error)
            self.errorMessage = errorMessage
            print("[SpotifyDevicesVM] Set errorMessage to: \(errorMessage)")
        }
    }
    
    /// Provides user-friendly error messages based on the underlying error
    private func getUserFriendlyErrorMessage(for error: Error) -> String {
        if let apiError = error as? SpotifyAPIService.APIError {
            switch apiError {
            case .requestFailed(let statusCode, let message):
                switch statusCode {
                case 401:
                    return "Authentication failed. Please try signing in again."
                case 403:
                    return "Access denied. Please check your Spotify permissions."
                case 404:
                    return "Spotify service not found. Please try again later."
                case 429:
                    return "Too many requests. Please wait a moment and try again."
                case 500...599:
                    return "Spotify service is temporarily unavailable. Please try again later."
                default:
                    return "Failed to connect to Spotify: \(message)"
                }
            case .playbackFailed:
                return "Failed to control playback. Please try again."
            }
        }
        
        // Handle network errors
        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet:
            return "No internet connection. Please check your network and try again."
        case NSURLErrorTimedOut:
            return "Connection timed out. Please try again."
        case NSURLErrorCannotConnectToHost:
            return "Cannot connect to Spotify. Please check your internet connection."
        default:
            return error.localizedDescription
        }
    }
}
