import Foundation
import Combine
import AppKit

/// Service for managing Spotify OAuth authentication flow
@MainActor
final class SpotifyAuthService: ObservableObject {
    var objectWillChange = ObservableObjectPublisher()
    
    static let shared = SpotifyAuthService()
    
    @Published var isAuthenticated = false
    @Published var authError: String?
    
    private var codeVerifier: String?
    private let keychainKey = "spotifyAuthToken"
    
    // Token refresh synchronization
    private var refreshTask: Task<String, Error>?
    
    private init() {
        // All properties are now initialized with default values
        // Safe to call method that accesses properties
        checkAuthenticationStatus()
    }
    
    // MARK: - Public Methods
    
    /// Initiates the OAuth authentication flow by opening Spotify's authorization URL
    func beginAuthentication() {
        print("[SpotifyAuth] ===== BEGIN AUTHENTICATION =====")
        print("[SpotifyAuth] Current auth status: \(isAuthenticated)")
        
        // Generate PKCE codes
        let verifier = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.generateCodeChallenge(from: verifier)
        
        // Store verifier for later use in callback
        self.codeVerifier = verifier
        print("[SpotifyAuth] Generated code verifier and challenge")
        
        // Build authorization URL
        var components = URLComponents(string: SpotifyConfig.spotifyAuthURL.absoluteString)!
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
            print("[SpotifyAuth] ERROR: Failed to construct authorization URL")
            return
        }
        
        print("[SpotifyAuth] Opening Spotify authorization URL: \(url.absoluteString)")
        
        // Open in browser
        let opened = NSWorkspace.shared.open(url)
        print("[SpotifyAuth] Browser opened: \(opened)")
    }
    
    /// Handles the OAuth callback with authorization code
    func handleCallback(url: URL) async {
        print("[SpotifyAuth] Handling callback URL: \(url.absoluteString)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            authError = "Invalid callback URL"
            print("[SpotifyAuth] ERROR: Invalid callback URL or missing code parameter")
            return
        }
        
        guard let verifier = codeVerifier else {
            authError = "Code verifier not found"
            print("[SpotifyAuth] ERROR: Code verifier not found")
            return
        }
        
        // Clear any existing tokens before attempting new exchange
        // This prevents showing "connected" status with stale tokens if exchange fails
        do {
            try KeychainService.shared.delete(forKey: keychainKey)
            isAuthenticated = false
            print("[SpotifyAuth] Cleared existing tokens before exchange")
        } catch {
            print("[SpotifyAuth] No existing tokens to clear or error clearing: \(error)")
        }
        
        do {
            try await exchangeCodeForToken(code: code, codeVerifier: verifier)
            self.codeVerifier = nil // Clear after use
            print("[SpotifyAuth] Token exchange successful")
        } catch {
            authError = "Token exchange failed: \(error.localizedDescription)"
            print("[SpotifyAuth] ERROR: Token exchange failed: \(error)")
        }
    }
    
    /// Returns a valid access token, refreshing if necessary
    func getValidAccessToken() async throws -> String {
        print("[SpotifyAuth] getValidAccessToken() called")
        
        guard let token = try KeychainService.shared.retrieve(SpotifyAuthToken.self, forKey: keychainKey) else {
            print("[SpotifyAuth] ERROR: No token found in keychain - throwing notAuthenticated")
            throw SpotifyAuthError.notAuthenticated
        }
        
        print("[SpotifyAuth] Token found in keychain, checking expiry...")
        print("[SpotifyAuth] Token issued at: \(token.issuedAt)")
        print("[SpotifyAuth] Token expires at: \(token.expiryDate)")
        print("[SpotifyAuth] Current time: \(Date())")
        print("[SpotifyAuth] Token expiresIn: \(token.expiresIn) seconds")
        
        // Check if token is expired (with 5 minute buffer)
        let bufferTime: TimeInterval = 300 // 5 minutes
        let now = Date()
        let expiryThreshold = now.addingTimeInterval(bufferTime)
        
        print("[SpotifyAuth] Expiry threshold (now + 5min): \(expiryThreshold)")
        print("[SpotifyAuth] Is expired? \(expiryThreshold >= token.expiryDate)")
        
        if expiryThreshold >= token.expiryDate {
            // Token is expired or about to expire, refresh it
            print("[SpotifyAuth] Token is expired or expiring soon, refreshing...")
            
            // Check if a refresh is already in progress
            if let existingTask = refreshTask {
                print("[SpotifyAuth] Refresh already in progress, waiting for existing task...")
                return try await existingTask.value
            }
            
            // Create a new refresh task
            print("[SpotifyAuth] Starting new refresh task...")
            let task = Task<String, Error> {
                defer {
                    print("[SpotifyAuth] Clearing refresh task")
                    self.refreshTask = nil
                }
                return try await self.refreshAccessToken(refreshToken: token.refreshToken)
            }
            
            refreshTask = task
            return try await task.value
        }
        
        print("[SpotifyAuth] Token is valid, returning access token")
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
            print("[SpotifyAuth] Checked auth status in init: \(isAuthenticated ? "authenticated (token found)" : "not authenticated (no token)")")
        } catch {
            isAuthenticated = false
            print("[SpotifyAuth] Checked auth status in init: not authenticated (error: \(error))")
        }
    }
    
    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws {
        let url = SpotifyConfig.tokenExchangeURL
        print("[SpotifyAuth] ===== TOKEN EXCHANGE STARTED =====")
        print("[SpotifyAuth] Exchanging code for token at: \(url.absoluteString)")
        print("[SpotifyAuth] Requested scopes: '\(SpotifyConfig.scopes.joined(separator: " "))'")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "code": code,
            "code_verifier": codeVerifier,
            "redirect_uri": SpotifyConfig.redirectURI
        ]
        
        print("[SpotifyAuth] Exchange request body: \(body)")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[SpotifyAuth] ERROR: Invalid response type")
            throw SpotifyAuthError.serverError
        }
        
        print("[SpotifyAuth] Backend response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAuth] ERROR: Backend returned \(httpResponse.statusCode): \(errorBody)")
            throw SpotifyAuthError.serverError
        }
        
        let token = try JSONDecoder().decode(SpotifyAuthToken.self, from: data)
        print("[SpotifyAuth] Token exchange successful")
        print("[SpotifyAuth] Received scopes: '\(token.scope)'")
        print("[SpotifyAuth] Token expires in: \(token.expiresIn) seconds")
        
        // Validate that received scopes match requested scopes
        let requestedScopes = SpotifyConfig.scopes.joined(separator: " ")
        if token.scope != requestedScopes {
            print("[SpotifyAuth] WARNING: Scope mismatch detected!")
            print("[SpotifyAuth] Requested: '\(requestedScopes)'")
            print("[SpotifyAuth] Received: '\(token.scope)'")
            print("[SpotifyAuth] Missing scopes: \(requestedScopes.split(separator: " ").filter { !token.scope.contains($0) })")
            print("[SpotifyAuth] Extra scopes: \(token.scope.split(separator: " ").filter { !requestedScopes.contains($0) })")
        } else {
            print("[SpotifyAuth] Scopes match perfectly ✓")
        }
        
        try KeychainService.shared.save(token, forKey: keychainKey)
        print("[SpotifyAuth] Token saved to keychain successfully")
        print("[SpotifyAuth] ===== TOKEN EXCHANGE COMPLETED =====")
        
        isAuthenticated = true
        authError = nil
    }
    
    private func refreshAccessToken(refreshToken: String) async throws -> String {
        let url = SpotifyConfig.tokenRefreshURL
        print("[SpotifyAuth] ===== TOKEN REFRESH STARTED =====")
        print("[SpotifyAuth] Refreshing access token at: \(url.absoluteString)")
        
        // Log current token scopes for comparison
        if let currentToken = try KeychainService.shared.retrieve(SpotifyAuthToken.self, forKey: keychainKey) {
            print("[SpotifyAuth] Current token scopes: '\(currentToken.scope)'")
            print("[SpotifyAuth] Expected scopes: '\(SpotifyConfig.scopes.joined(separator: " "))'")
            print("[SpotifyAuth] Scope match: \(currentToken.scope == SpotifyConfig.scopes.joined(separator: " "))")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "refresh_token": refreshToken
        ]
        
        print("[SpotifyAuth] Refresh request body: \(body)")
        print("[SpotifyAuth] NOTE: No scope parameter included in refresh request")
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[SpotifyAuth] ERROR: Invalid response type during refresh")
            throw SpotifyAuthError.serverError
        }
        
        print("[SpotifyAuth] Refresh response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAuth] ERROR: Refresh failed with \(httpResponse.statusCode): \(errorBody)")
            print("[SpotifyAuth] ERROR: Full response headers: \(httpResponse.allHeaderFields)")
            
            // Try to parse error details
            if let errorJson = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("[SpotifyAuth] ERROR: Parsed error response: \(errorJson)")
                if let error = errorJson["error"] as? String {
                    print("[SpotifyAuth] ERROR: Error type: \(error)")
                }
                if let errorDescription = errorJson["error_description"] as? String {
                    print("[SpotifyAuth] ERROR: Error description: \(errorDescription)")
                }
            }
            
            throw SpotifyAuthError.serverError
        }
        
        let newToken = try JSONDecoder().decode(SpotifyAuthToken.self, from: data)
        print("[SpotifyAuth] New token received with scopes: '\(newToken.scope)'")
        print("[SpotifyAuth] New token expires in: \(newToken.expiresIn) seconds")
        
        // Check if scopes changed during refresh
        if let oldToken = try KeychainService.shared.retrieve(SpotifyAuthToken.self, forKey: keychainKey) {
            if oldToken.scope != newToken.scope {
                print("[SpotifyAuth] WARNING: Scopes changed during refresh!")
                print("[SpotifyAuth] Old scopes: '\(oldToken.scope)'")
                print("[SpotifyAuth] New scopes: '\(newToken.scope)'")
            }
        }
        
        try KeychainService.shared.save(newToken, forKey: keychainKey)
        print("[SpotifyAuth] Token refreshed and saved successfully")
        print("[SpotifyAuth] ===== TOKEN REFRESH COMPLETED =====")
        
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
