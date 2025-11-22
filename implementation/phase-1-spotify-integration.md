# Spotify Integration Implementation Plan

## Overview
Implement OAuth PKCE authentication flow for Spotify, with token management in Keychain and direct Spotify Web API integration.

**Backend**: `https://slideshow-buddy-server.onrender.com` (OAuth token exchange only)  
**Redirect URI**: `com.electricslideshow://callback`  
**Required Scopes**: `playlist-read-private playlist-read-collaborative user-library-read user-read-playback-state user-modify-playback-state`

---

## Stage 1: Configuration & Models

### Create `Config/SpotifyConfig.swift`
```swift
struct SpotifyConfig {
    static let clientId = "YOUR_SPOTIFY_CLIENT_ID" // From Spotify Dashboard
    static let redirectURI = "com.electricslideshow://callback"
    static let tokenExchangeURL = URL(string: "https://slideshow-buddy-server.onrender.com/auth/spotify/token")!
    static let tokenRefreshURL = URL(string: "https://slideshow-buddy-server.onrender.com/auth/spotify/refresh")!
    
    static let scopes = [
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-library-read",
        "user-read-playback-state",
        "user-modify-playback-state"
    ]
    
    static let spotifyAuthURL = URL(string: "https://accounts.spotify.com/authorize")!
    static let spotifyAPIBaseURL = URL(string: "https://api.spotify.com/v1")!
}
```

### Create `Models/SpotifyAuthToken.swift`
```swift
struct SpotifyAuthToken: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int // seconds
    let tokenType: String
    let scope: String
    
    var expiryDate: Date {
        Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}
```

### Update `Info.plist`
Add URL scheme handler:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.electricslideshow</string>
        </array>
        <key>CFBundleURLName</key>
        <string>Spotify OAuth Callback</string>
    </dict>
</array>
```

---

## Stage 2: Keychain Token Storage

### Create `Services/KeychainService.swift`
```swift
import Foundation
import Security

final class KeychainService {
    private let service = "com.electricslideshow.spotify"
    
    enum KeychainError: Error {
        case itemNotFound
        case unexpectedData
        case unhandledError(status: OSStatus)
    }
    
    func save(_ token: SpotifyAuthToken) throws {
        let data = try JSONEncoder().encode(token)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "spotify-token",
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary) // Delete existing
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    func load() throws -> SpotifyAuthToken {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "spotify-token",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw status == errSecItemNotFound ? KeychainError.itemNotFound : KeychainError.unhandledError(status: status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }
        
        return try JSONDecoder().decode(SpotifyAuthToken.self, from: data)
    }
    
    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "spotify-token"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}
```

---

## Stage 3: PKCE Helper

### Create `Helpers/PKCEHelper.swift`
```swift
import Foundation
import CryptoKit

struct PKCEHelper {
    static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }
    
    static func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
```

---

## Stage 4: Spotify Auth Service

### Create `Services/SpotifyAuthService.swift`
```swift
import Foundation
import AppKit

@MainActor
final class SpotifyAuthService: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var userDisplayName: String?
    
    private let keychainService = KeychainService()
    private var currentCodeVerifier: String?
    
    init() {
        checkAuthStatus()
    }
    
    // MARK: - Public API
    
    func beginAuthentication() {
        let verifier = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.generateCodeChallenge(from: verifier)
        currentCodeVerifier = verifier
        
        var components = URLComponents(url: SpotifyConfig.spotifyAuthURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: SpotifyConfig.scopes.joined(separator: " "))
        ]
        
        NSWorkspace.shared.open(components.url!)
    }
    
    func handleCallback(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let verifier = currentCodeVerifier else {
            throw AuthError.invalidCallback
        }
        
        try await exchangeCodeForToken(code: code, verifier: verifier)
        currentCodeVerifier = nil
        checkAuthStatus()
    }
    
    func signOut() throws {
        try keychainService.delete()
        isAuthenticated = false
        userDisplayName = nil
    }
    
    func getValidAccessToken() async throws -> String {
        guard let token = try? keychainService.load() else {
            throw AuthError.notAuthenticated
        }
        
        // Check if token is expired (with 5 min buffer)
        if Date().addingTimeInterval(300) >= token.expiryDate {
            return try await refreshAccessToken(refreshToken: token.refreshToken)
        }
        
        return token.accessToken
    }
    
    // MARK: - Private
    
    private func checkAuthStatus() {
        if let token = try? keychainService.load() {
            isAuthenticated = true
            // Optionally fetch user profile here
        }
    }
    
    private func exchangeCodeForToken(code: String, verifier: String) async throws {
        var request = URLRequest(url: SpotifyConfig.tokenExchangeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["code": code, "code_verifier": verifier]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.tokenExchangeFailed
        }
        
        let token = try JSONDecoder().decode(SpotifyAuthToken.self, from: data)
        try keychainService.save(token)
    }
    
    private func refreshAccessToken(refreshToken: String) async throws -> String {
        var request = URLRequest(url: SpotifyConfig.tokenRefreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.tokenRefreshFailed
        }
        
        let token = try JSONDecoder().decode(SpotifyAuthToken.self, from: data)
        try keychainService.save(token)
        
        return token.accessToken
    }
    
    enum AuthError: Error {
        case invalidCallback
        case notAuthenticated
        case tokenExchangeFailed
        case tokenRefreshFailed
    }
}
```

---

## Stage 5: Handle URL Callbacks in App

### Update `Electric_SlideshowApp.swift`
```swift
import SwiftUI

@main
struct Electric_SlideshowApp: App {
    @StateObject private var photoService = PhotoLibraryService()
    @StateObject private var spotifyAuthService = SpotifyAuthService()
    
    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(photoService)
                .environmentObject(spotifyAuthService)
                .onOpenURL { url in
                    Task {
                        if url.scheme == "com.electricslideshow" {
                            try? await spotifyAuthService.handleCallback(url: url)
                        }
                    }
                }
        }
    }
}
```

---

## Stage 6: Music View UI

### Create `ViewModels/MusicViewModel.swift`
```swift
@MainActor
final class MusicViewModel: ObservableObject {
    @Published var errorMessage: String?
    
    private let authService: SpotifyAuthService
    
    init(authService: SpotifyAuthService) {
        self.authService = authService
    }
    
    func connectSpotify() {
        authService.beginAuthentication()
    }
    
    func disconnect() {
        do {
            try authService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }
}
```

### Create `Views/MusicView.swift`
```swift
struct MusicView: View {
    @EnvironmentObject private var authService: SpotifyAuthService
    @StateObject private var viewModel: MusicViewModel
    
    init() {
        self._viewModel = StateObject(wrappedValue: MusicViewModel(authService: SpotifyAuthService()))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if authService.isAuthenticated {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    
                    Text("Connected to Spotify")
                        .font(.title2)
                    
                    if let name = authService.userDisplayName {
                        Text(name)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("Disconnect") {
                        viewModel.disconnect()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("Connect Spotify")
                        .font(.title2)
                    
                    Text("Connect your Spotify account to add music to slideshows")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Connect with Spotify") {
                        viewModel.connectSpotify()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
```

### Update `AppMainView.swift`
```swift
case .music:
    MusicView()
        .environmentObject(spotifyAuthService)
```

---

## Testing Checklist

1. ✓ Click "Connect with Spotify" opens browser
2. ✓ User authenticates in Spotify
3. ✓ Redirect back to app with code
4. ✓ Token exchange succeeds
5. ✓ Token stored in Keychain
6. ✓ UI updates to "Connected"
7. ✓ App restart preserves authentication
8. ✓ Token refresh works when expired
9. ✓ Disconnect clears token
10. ✓ Error handling for failed auth

---

## Next Steps (After This Works)

- Stage 7: `SpotifyAPIService` for direct API calls
- Stage 8: Fetch user playlists & tracks
- Stage 9: App-local playlist creation flow
- Stage 10: Playback control integration
