import Foundation
import Combine

/// Service for making direct API calls to Spotify Web API
@MainActor
final class SpotifyAPIService: ObservableObject {
    private let authService: SpotifyAuthService
    private let baseURL = SpotifyConfig.spotifyAPIBaseURL
    
    init(authService: SpotifyAuthService) {
        self.authService = authService
    }
    
    // MARK: - User Profile
    
    func fetchUserProfile() async throws -> SpotifyUser {
        let url = baseURL.appendingPathComponent("me")
        print("[SpotifyAPI] Fetching user profile from: \(url.absoluteString)")
        
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[SpotifyAPI] ERROR: Invalid response type")
            throw APIError.requestFailed
        }
        
        print("[SpotifyAPI] Profile request status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAPI] ERROR: Profile request failed with \(httpResponse.statusCode): \(errorBody)")
            throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        return try JSONDecoder().decode(SpotifyUser.self, from: data)
    }
    
    // MARK: - Playlists
    
    func fetchUserPlaylists() async throws -> [SpotifyPlaylist] {
        let url = baseURL.appendingPathComponent("me/playlists")
        print("[SpotifyAPI] Fetching user playlists from: \(url.absoluteString)")
        
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[SpotifyAPI] ERROR: Invalid response type")
            throw APIError.requestFailed(statusCode: 0, message: "Invalid response")
        }
        
        print("[SpotifyAPI] Playlists request status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAPI] ERROR: Playlists request failed with \(httpResponse.statusCode): \(errorBody)")
            throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        let playlistsResponse = try JSONDecoder().decode(SpotifyPlaylistsResponse.self, from: data)
        return playlistsResponse.items
    }
    
    func fetchPlaylistTracks(playlistId: String) async throws -> [SpotifyTrack] {
        let url = baseURL.appendingPathComponent("playlists/\(playlistId)/tracks")
        print("[SpotifyAPI] Fetching playlist tracks from: \(url.absoluteString)")
        
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[SpotifyAPI] ERROR: Invalid response type")
            throw APIError.requestFailed(statusCode: 0, message: "Invalid response")
        }
        
        print("[SpotifyAPI] Playlist tracks request status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAPI] ERROR: Playlist tracks request failed with \(httpResponse.statusCode): \(errorBody)")
            throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        let tracksResponse = try JSONDecoder().decode(SpotifyTracksResponse.self, from: data)
        return tracksResponse.items.map { $0.track }
    }
    
    // MARK: - Saved Tracks
    
    func fetchSavedTracks(limit: Int = 50, offset: Int = 0) async throws -> [SpotifyTrack] {
        var components = URLComponents(url: baseURL.appendingPathComponent("me/tracks"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        print("[SpotifyAPI] Fetching saved tracks from: \(components.url!.absoluteString)")
        
        let token = try await authService.getValidAccessToken()
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[SpotifyAPI] ERROR: Invalid response type")
            throw APIError.requestFailed(statusCode: 0, message: "Invalid response")
        }
        
        print("[SpotifyAPI] Saved tracks request status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAPI] ERROR: Saved tracks request failed with \(httpResponse.statusCode): \(errorBody)")
            throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        let savedTracksResponse = try JSONDecoder().decode(SpotifySavedTracksResponse.self, from: data)
        return savedTracksResponse.items.map { $0.track }
    }
    
    // MARK: - Playback
    
    func startPlayback(trackURIs: [String], deviceId: String? = nil) async throws {
        let url = baseURL.appendingPathComponent("me/player/play")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = ["uris": trackURIs]
        if let deviceId = deviceId {
            body["device_id"] = deviceId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.playbackFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAPI] ERROR: Start playback failed with \(httpResponse.statusCode): \(errorBody)")
            throw APIError.playbackFailed
        }
    }
    
    func pausePlayback() async throws {
        let url = baseURL.appendingPathComponent("me/player/pause")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.playbackFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAPI] ERROR: Pause playback failed with \(httpResponse.statusCode): \(errorBody)")
            throw APIError.playbackFailed
        }
    }
    
    func skipToNext() async throws {
        let url = baseURL.appendingPathComponent("me/player/next")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.playbackFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAPI] ERROR: Skip to next failed with \(httpResponse.statusCode): \(errorBody)")
            throw APIError.playbackFailed
        }
    }
    
    func skipToPrevious() async throws {
        let url = baseURL.appendingPathComponent("me/player/previous")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.playbackFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAPI] ERROR: Skip to previous failed with \(httpResponse.statusCode): \(errorBody)")
            throw APIError.playbackFailed
        }
    }
    
    func getCurrentPlaybackState() async throws -> SpotifyPlaybackState? {
        let url = baseURL.appendingPathComponent("me/player")
        let token = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed(statusCode: 0, message: "Invalid response")
        }
        
        // 204 means no active playback
        if httpResponse.statusCode == 204 {
            return nil
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAPI] ERROR: Get playback state failed with \(httpResponse.statusCode): \(errorBody)")
            throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        return try JSONDecoder().decode(SpotifyPlaybackState.self, from: data)
    }
    
    enum APIError: LocalizedError {
        case requestFailed(statusCode: Int, message: String)
        case playbackFailed
        
        var errorDescription: String? {
            switch self {
            case .requestFailed(let statusCode, let message):
                return "Spotify API request failed (\(statusCode)): \(message)"
            case .playbackFailed:
                return "Failed to control playback"
            }
        }
    }
}
