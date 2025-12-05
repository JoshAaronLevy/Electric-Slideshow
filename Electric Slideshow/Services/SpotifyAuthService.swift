import Foundation
import Combine
import AppKit

/// Service for managing Spotify OAuth authentication flow
@MainActor
final class SpotifyAuthService: ObservableObject {
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
        print("[SpotifyAuth] Current auth status: \(isAuthenticated)")
        
        // Generate PKCE codes
        let verifier = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.generateCodeChallenge(from: verifier)
        
        // Store verifier for later use in callback
        self.codeVerifier = verifier
        
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
        
        // Open in browser
        let opened = NSWorkspace.shared.open(url)
    }
    
    /// Handles the OAuth callback with authorization code
    func handleCallback(url: URL) async {
        
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
        } catch {
            authError = "Token exchange failed: \(error.localizedDescription)"
            print("[SpotifyAuth] ERROR: Token exchange failed: \(error)")
        }
    }
    
    /// Returns a valid access token, refreshing if necessary
    func getValidAccessToken() async throws -> String {
        guard let token = try KeychainService.shared.retrieve(SpotifyAuthToken.self, forKey: keychainKey) else {
            print("[SpotifyAuth] ERROR: No token found in keychain - throwing notAuthenticated")
            PlayerInitLogger.shared.log(
                "ERROR: No token found in keychain - throwing notAuthenticated",
                source: "SpotifyAuth"
            )
            throw SpotifyAuthError.notAuthenticated
        }
        
        // Check if token is expired (with 5 minute buffer)
        let bufferTime: TimeInterval = 300 // 5 minutes
        let now = Date()
        let expiryThreshold = now.addingTimeInterval(bufferTime)
        
        if expiryThreshold >= token.expiryDate {
            // Check if a refresh is already in progress
            if let existingTask = refreshTask {
                print("[SpotifyAuth] Refresh already in progress, waiting for existing task...")
                PlayerInitLogger.shared.log(
                    "Refresh already in progress, waiting for existing task...",
                    source: "SpotifyAuth"
                )
                return try await existingTask.value
            }
            
            // Create a new refresh task
            let task = Task<String, Error> {
                defer {
                    print("[SpotifyAuth] Clearing refresh task")
                    self.refreshTask = nil
                }
                PlayerInitLogger.shared.log(
                    "Token expired, refreshing access token",
                    source: "SpotifyAuth"
                )
                return try await self.refreshAccessToken(refreshToken: token.refreshToken)
            }
            
            refreshTask = task
            return try await task.value
        }
        
        print("[SpotifyAuth] Token \(token.accessToken)")
        let tokenPrefix = String(token.accessToken.prefix(8))
        PlayerInitLogger.shared.log(
            "Valid token retrieved (prefix: \(tokenPrefix)...)",
            source: "SpotifyAuth"
        )
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
            PlayerInitLogger.shared.log(
                "Checked auth status in init: \(isAuthenticated ? "authenticated (token found)" : "not authenticated (no token)")",
                source: "SpotifyAuth"
            )
        } catch {
            isAuthenticated = false
            print("[SpotifyAuth] Checked auth status in init: not authenticated (error: \(error))")
            PlayerInitLogger.shared.log(
                "Checked auth status in init: not authenticated (error: \(error))",
                source: "SpotifyAuth"
            )
        }
    }
    
    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws {
        let url = SpotifyConfig.tokenExchangeURL
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
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[SpotifyAuth] ERROR: Backend returned \(httpResponse.statusCode): \(errorBody)")
            throw SpotifyAuthError.serverError
        }
        
        let token = try JSONDecoder().decode(SpotifyAuthToken.self, from: data)
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
        
        isAuthenticated = true
        authError = nil
    }
    
    private func refreshAccessToken(refreshToken: String) async throws -> String {
        let url = SpotifyConfig.tokenRefreshURL
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
        
        // Decode the token response
        let decodedToken: SpotifyAuthToken
        do {
            decodedToken = try JSONDecoder().decode(SpotifyAuthToken.self, from: data)
        } catch {
            print("[SpotifyAuth] ERROR: Failed to decode token response")
            print("[SpotifyAuth] ERROR: Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("[SpotifyAuth] ERROR: Missing key '\(key.stringValue)' - \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("[SpotifyAuth] ERROR: Type mismatch for type '\(type)' - \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("[SpotifyAuth] ERROR: Value not found for type '\(type)' - \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("[SpotifyAuth] ERROR: Data corrupted - \(context.debugDescription)")
                @unknown default:
                    print("[SpotifyAuth] ERROR: Unknown decoding error")
                }
            }
            let responseString = String(data: data, encoding: .utf8) ?? "(unable to decode response)"
            print("[SpotifyAuth] ERROR: Response body: \(responseString)")
            throw error
        }
        
        print("[SpotifyAuth] New token received with scopes: '\(decodedToken.scope)'")
        print("[SpotifyAuth] New token expires in: \(decodedToken.expiresIn) seconds")
        
        // Spotify's token refresh endpoint doesn't return a new refresh token.
        // The existing refresh token remains valid and should be preserved.
        let tokenToSave: SpotifyAuthToken
        if decodedToken.refreshToken.isEmpty {
            print("[SpotifyAuth] Refresh token not included in response - preserving original refresh token")
            tokenToSave = SpotifyAuthToken(
                accessToken: decodedToken.accessToken,
                refreshToken: refreshToken, // Use the original refresh token passed to this function
                expiresIn: decodedToken.expiresIn,
                tokenType: decodedToken.tokenType,
                scope: decodedToken.scope,
                issuedAt: decodedToken.issuedAt
            )
        } else {
            tokenToSave = decodedToken
        }
        
        // Check if scopes changed during refresh
        if let oldToken = try KeychainService.shared.retrieve(SpotifyAuthToken.self, forKey: keychainKey) {
            if oldToken.scope != tokenToSave.scope {
                print("[SpotifyAuth] WARNING: Scopes changed during refresh!")
                print("[SpotifyAuth] Old scopes: '\(oldToken.scope)'")
                print("[SpotifyAuth] New scopes: '\(tokenToSave.scope)'")
            }
        }
        
        try KeychainService.shared.save(tokenToSave, forKey: keychainKey)
        print("[SpotifyAuth] Token refreshed and saved successfully")
        print("[SpotifyAuth] ===== TOKEN REFRESH COMPLETED =====")
        
        return tokenToSave.accessToken
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
