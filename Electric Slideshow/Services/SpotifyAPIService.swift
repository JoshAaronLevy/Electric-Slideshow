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
        
        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {

            print("[SpotifyAPI] ERROR: Invalid response type, status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")

            throw APIError.requestFailed(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1,
                message: "Unexpected response from Spotify API"
            )
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

    // MARK: - Devices

    /// Fetches available Spotify devices for playback via backend proxy
    func fetchAvailableDevices() async throws -> [SpotifyDevice] {
        // Use backend proxy instead of direct Spotify API call
        guard let backendURL = URL(string: "https://electric-slideshow-server.onrender.com/api/spotify/devices") else {
            throw APIError.requestFailed(statusCode: 0, message: "Invalid backend proxy URL")
        }
        
        print("[SpotifyAPI] Fetching available devices from backend proxy: \(backendURL.absoluteString)")
        
        let token = try await authService.getValidAccessToken()
        print("[SpotifyAPI] Got valid access token: \(token.prefix(10))...")

        var request = URLRequest(url: backendURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[SpotifyAPI] ERROR: Invalid response type - not HTTPURLResponse")
            throw APIError.requestFailed(statusCode: 0, message: "Invalid response")
        }
        
        print("[SpotifyAPI] Response status code: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAPI] ERROR: Backend proxy devices request failed with \(httpResponse.statusCode): \(errorBody)")
            print("[SpotifyAPI] ERROR: Response headers: \(httpResponse.allHeaderFields)")
            throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: errorBody)
        }

        print("[SpotifyAPI] Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
        
        do {
            let decoder = JSONDecoder()
            let devicesResponse = try decoder.decode(SpotifyDevicesResponse.self, from: data)

            let devices = devicesResponse.data.devices
            print("[SpotifyAPI] Successfully decoded \(devices.count) devices")
            return devices
        } catch {
            print("[SpotifyAPI] ERROR: Failed to decode devices response: \(error)")
            print("[SpotifyAPI] ERROR: Decoding error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    struct SpotifyPlaybackError: Decodable, Error {
        let status: Int?
        let message: String?
        let reason: String?
    }

    enum PlaybackError: LocalizedError {
        case noActiveDevice(message: String)
        case generic(message: String)

        var errorDescription: String? {
            switch self {
            case .noActiveDevice(let message):
                return message
            case .generic(let message):
                return message
            }
        }
    }

    func startPlayback(trackURIs: [String], deviceId: String? = nil) async throws {
        // Build URL with optional ?device_id=...
        var components = URLComponents(url: baseURL.appendingPathComponent("me/player/play"),
                                    resolvingAgainstBaseURL: false)!
        if let deviceId = deviceId {
            components.queryItems = [URLQueryItem(name: "device_id", value: deviceId)]
        }

        guard let url = components.url else {
            throw PlaybackError.generic(message: "Invalid playback URL")
        }

        let token = try await authService.getValidAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // If you have explicit track URIs, pass them; if you later switch to playlist context,
        // you’ll change this to `context_uri`.
        var body: [String: Any] = [:]
        if !trackURIs.isEmpty {
            body["uris"] = trackURIs
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaybackError.generic(message: "Invalid response from Spotify")
        }

        if (200..<300).contains(httpResponse.statusCode) {
            return
        }

        // Existing error handling remains the same
        let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
        if let errorPayload = try? JSONDecoder().decode(SpotifyPlaybackError.self, from: data),
        let reason = errorPayload.reason {
            if reason == "NO_ACTIVE_DEVICE" {
                throw PlaybackError.noActiveDevice(
                    message: errorPayload.message ?? "No active Spotify device found."
                )
            } else {
                throw PlaybackError.generic(
                    message: errorPayload.message ?? "Playback failed."
                )
            }
        }
        throw PlaybackError.generic(message: errorBody)
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
            case let .requestFailed(statusCode, message):
                return "Failed Spotify API call (\(statusCode)): \(message)"
            case .playbackFailed:
                return "Failed to control playback"
            }
        }
    }
}

// MARK: - Device Models

struct SpotifyDevicesResponse: Decodable {
    let success: Bool
    let data: DevicesContainer
    let timestamp: String?

    struct DevicesContainer: Decodable {
        let devices: [SpotifyDevice]
    }
}

struct SpotifyDevice: Decodable, Identifiable {
    let id: String
    let name: String
    let type: String
    let is_active: Bool
    let is_restricted: Bool
    let volume_percent: Int?
    let is_private_session: Bool?
    let is_group: Bool?
    let device_id: String?

    var deviceId: String { device_id ?? id }
}
