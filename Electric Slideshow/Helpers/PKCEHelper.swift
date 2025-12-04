import Foundation
import CryptoKit

/// Helper for PKCE (Proof Key for Code Exchange) OAuth flow
struct PKCEHelper {
    /// Generates a random code verifier string (43-128 characters)
    static func generateCodeVerifier() -> String {
        let length = 64 // Within valid range of 43-128
        let charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        var verifier = ""
        
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<charset.count)
            let character = charset[charset.index(charset.startIndex, offsetBy: randomIndex)]
            verifier.append(character)
        }
        
        return verifier
    }
    
    /// Generates a code challenge from a verifier using SHA256 hash
    static func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .ascii) else {
            fatalError("Failed to convert verifier to ASCII data")
        }
        
        let hash = SHA256.hash(data: data)
        let base64 = Data(hash).base64EncodedString()
        
        // Convert to base64url encoding (replace + with -, / with _, remove =)
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return base64url
    }
}
