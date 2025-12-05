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

    // MARK: - Web Playback Token

    /// Returns a Spotify access token suitable for use with the
    /// Spotify Web Playback SDK on the JS side.
    ///
    /// For now this is just your regular access token; make sure
    /// the app is authorized with the required scopes:
    /// - streaming
    /// - user-read-email
    /// - user-read-private
    /// - user-modify-playback-state
    /// - user-read-playback-state
    func getWebPlaybackAccessToken() async throws -> String {
        return try await authService.getValidAccessToken()
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
    
    /// Fetches metadata for a list of Spotify track URIs using the `/tracks` endpoint.
    /// Spotify allows up to 50 IDs per request, so this batches as needed.
    func fetchTracks(forURIs uris: [String]) async throws -> [SpotifyTrack] {
        // Extract track IDs from URIs (e.g., "spotify:track:123")
        let trackIds = uris.compactMap(Self.trackId(fromURI:))
        guard !trackIds.isEmpty else { return [] }
        
        let token = try await authService.getValidAccessToken()
        var results: [SpotifyTrack] = []
        
        for batch in trackIds.chunked(into: 50) {
            var components = URLComponents(
                url: baseURL.appendingPathComponent("tracks"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [
                URLQueryItem(name: "ids", value: batch.joined(separator: ","))
            ]
            
            guard let url = components.url else { continue }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[SpotifyAPI] ERROR: Invalid response type")
                throw APIError.requestFailed(statusCode: 0, message: "Invalid response")
            }
            
            print("[SpotifyAPI] Fetch tracks request status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
                print("[SpotifyAPI] ERROR: Fetch tracks failed with \(httpResponse.statusCode): \(errorBody)")
                throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: errorBody)
            }
            
            let tracksResponse = try JSONDecoder().decode(SpotifyTracksListResponse.self, from: data)
            results.append(contentsOf: tracksResponse.tracks)
        }
        
        return results
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

    func startPlayback(trackURIs: [String], deviceId: String? = nil, startPositionMs: Int? = nil) async throws {
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
        if let startPositionMs {
            body["position_ms"] = startPositionMs
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
    
    func pausePlayback(deviceId: String? = nil) async throws {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("me/player/pause"),
            resolvingAgainstBaseURL: false
        )!
        if let deviceId {
            components.queryItems = [URLQueryItem(name: "device_id", value: deviceId)]
        }

        guard let url = components.url else {
            throw APIError.playbackFailed
        }

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

    func resumePlayback(deviceId: String? = nil) async throws {
        // Build URL with optional ?device_id=...
        var components = URLComponents(
            url: baseURL.appendingPathComponent("me/player/play"),
            resolvingAgainstBaseURL: false
        )!

        if let deviceId = deviceId {
            components.queryItems = [URLQueryItem(name: "device_id", value: deviceId)]
        }

        guard let url = components.url else {
            throw APIError.playbackFailed
        }

        let token = try await authService.getValidAccessToken()

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // NOTE: no body → Spotify resumes current playback position

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.playbackFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAPI] ERROR: Resume playback failed with \(httpResponse.statusCode): \(errorBody)")
            throw APIError.playbackFailed
        }
    }

    /// Seeks the current track to the given position (in milliseconds).
    func seekToPosition(positionMs: Int) async throws {
        try await seek(to: positionMs)
    }

    func seek(to positionMs: Int, deviceId: String? = nil) async throws {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("me/player/seek"),
            resolvingAgainstBaseURL: false
        )!
        var queryItems = [URLQueryItem(name: "position_ms", value: "\(positionMs)")]
        if let deviceId {
            queryItems.append(URLQueryItem(name: "device_id", value: deviceId))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.playbackFailed
        }

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
            print("[SpotifyAPI] ERROR: Seek failed with \(httpResponse.statusCode): \(errorBody)")
            throw APIError.playbackFailed
        }
    }

    func setVolume(_ volumePercent: Int, deviceId: String? = nil) async throws {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("me/player/volume"),
            resolvingAgainstBaseURL: false
        )!
        var queryItems = [URLQueryItem(name: "volume_percent", value: "\(volumePercent)")]
        if let deviceId {
            queryItems.append(URLQueryItem(name: "device_id", value: deviceId))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.playbackFailed
        }

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
            print("[SpotifyAPI] ERROR: Set volume failed with \(httpResponse.statusCode): \(errorBody)")
            throw APIError.playbackFailed
        }
    }

    func skipToNext(deviceId: String? = nil) async throws {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("me/player/next"),
            resolvingAgainstBaseURL: false
        )!
        if let deviceId {
            components.queryItems = [URLQueryItem(name: "device_id", value: deviceId)]
        }

        guard let url = components.url else {
            throw APIError.playbackFailed
        }

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
    
    func skipToPrevious(deviceId: String? = nil) async throws {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("me/player/previous"),
            resolvingAgainstBaseURL: false
        )!
        if let deviceId {
            components.queryItems = [URLQueryItem(name: "device_id", value: deviceId)]
        }

        guard let url = components.url else {
            throw APIError.playbackFailed
        }

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

    // MARK: - Shuffle / Repeat

    /// Toggle shuffle on/off for the current user's playback.
    func setShuffle(isOn: Bool) async throws {
        let token = try await authService.getValidAccessToken()  // or your equivalent

        var components = URLComponents(string: "\(baseURL)/me/player/shuffle")!
        components.queryItems = [
            URLQueryItem(name: "state", value: isOn ? "true" : "false")
            // Optionally: URLQueryItem(name: "device_id", value: currentDeviceId)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        _ = try await URLSession.shared.data(for: request)
    }

    /// Set repeat mode for the current user's playback.
    ///
    /// We map `PlaybackRepeatMode.off` → "off" and `.all` → "context"
    /// (repeat the current playlist/queue).
    func setRepeat(mode: PlaybackRepeatMode) async throws {
        let token = try await authService.getValidAccessToken()  // or your equivalent

        let state: String
        switch mode {
        case .off:
            state = "off"
        case .all:
            state = "context"
        }

        var components = URLComponents(string: "\(baseURL)/me/player/repeat")!
        components.queryItems = [
            URLQueryItem(name: "state", value: state)
            // Optionally: URLQueryItem(name: "device_id", value: currentDeviceId)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        _ = try await URLSession.shared.data(for: request)
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

// MARK: - Helpers

private extension Array {
    /// Returns an array of arrays, each with at most `size` elements.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        var result: [[Element]] = []
        var index = startIndex
        
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<end]))
            index = end
        }
        
        return result
    }
}

private extension SpotifyAPIService {
    static func trackId(fromURI uri: String) -> String? {
        let components = uri.split(separator: ":")
        guard components.count >= 3 else { return nil }
        return String(components[2])
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
