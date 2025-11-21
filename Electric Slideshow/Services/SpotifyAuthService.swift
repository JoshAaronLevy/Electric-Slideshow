import Foundation
import SwiftUI

/// Service for managing Spotify OAuth authentication flow
@MainActor
final class SpotifyAuthService: ObservableObject {
    static let shared = SpotifyAuthService()
    
    @Published var isAuthenticated = false
    @Published var authError: String?
    
    private var codeVerifier: String?
    private let keychainKey = "spotifyAuthToken"
    
    private init() {
        checkAuthenticationStatus()
    }
    
    // MARK: - Public Methods
    
    /// Initiates the OAuth authentication flow by opening Spotify's authorization URL
    func beginAuthentication() {
        // Generate PKCE codes
        let verifier = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.generateCodeChallenge(from: verifier)
        
        // Store verifier for later use in callback
        self.codeVerifier = verifier
        
        // Build authorization URL
        var components = URLComponents(string: SpotifyConfig.spotifyAuthURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: SpotifyConfig.scopes.joined(separator: " "))
        ]
        
        guard let url = components.url else {
            authError = "Failed to construct authorization URL"
            return
        }
        
        // Open in browser
        NSWorkspace.shared.open(url)
    }
    
    /// Handles the OAuth callback with authorization code
    func handleCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            authError = "Invalid callback URL"
            return
        }
        
        guard let verifier = codeVerifier else {
            authError = "Code verifier not found"
            return
        }
        
        do {
            try await exchangeCodeForToken(code: code, codeVerifier: verifier)
            self.codeVerifier = nil // Clear after use
        } catch {
            authError = "Token exchange failed: \(error.localizedDescription)"
        }
    }
    
    /// Returns a valid access token, refreshing if necessary
    func getValidAccessToken() async throws -> String {
        guard let token = try KeychainService.shared.retrieve(SpotifyAuthToken.self, forKey: keychainKey) else {
            throw SpotifyAuthError.notAuthenticated
        }
        
        // Check if token is expired (with 5 minute buffer)
        let bufferTime: TimeInterval = 300 // 5 minutes
        if Date().addingTimeInterval(bufferTime) >= token.expiryDate {
            // Token is expired or about to expire, refresh it
            return try await refreshAccessToken(refreshToken: token.refreshToken)
        }
        
        return token.accessToken
    }
    
    /// Signs out by deleting stored tokens
    func signOut() {
        do {
            try KeychainService.shared.delete(forKey: keychainKey)
            isAuthenticated = false
        } catch {
            authError = "Failed to sign out: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Methods
    
    private func checkAuthenticationStatus() {
        do {
            let token = try KeychainService.shared.retrieve(SpotifyAuthToken.self, forKey: keychainKey)
            isAuthenticated = token != nil
        } catch {
            isAuthenticated = false
        }
    }
    
    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws {
        guard let url = URL(string: SpotifyConfig.tokenExchangeURL) else {
            throw SpotifyAuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "code": code,
            "code_verifier": codeVerifier,
            "redirect_uri": SpotifyConfig.redirectURI
        ]
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SpotifyAuthError.serverError
        }
        
        let token = try JSONDecoder().decode(SpotifyAuthToken.self, from: data)
        try KeychainService.shared.save(token, forKey: keychainKey)
        
        isAuthenticated = true
        authError = nil
    }
    
    private func refreshAccessToken(refreshToken: String) async throws -> String {
        guard let url = URL(string: SpotifyConfig.tokenRefreshURL) else {
            throw SpotifyAuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "refresh_token": refreshToken
        ]
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SpotifyAuthError.serverError
        }
        
        let newToken = try JSONDecoder().decode(SpotifyAuthToken.self, from: data)
        try KeychainService.shared.save(newToken, forKey: keychainKey)
        
        return newToken.accessToken
    }
}

// MARK: - Errors

enum SpotifyAuthError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Spotify"
        case .invalidURL:
            return "Invalid request URL"
        case .serverError:
            return "Server returned an error"
        }
    }
}
