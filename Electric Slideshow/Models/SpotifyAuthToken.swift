//
//  SpotifyAuthToken.swift
//  Electric Slideshow
//
//  Created by GitHub Copilot on 11/21/25.
//

import Foundation

struct SpotifyAuthToken: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int // seconds
    let tokenType: String
    let scope: String
    let issuedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
        case issuedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        tokenType = try container.decode(String.self, forKey: .tokenType)
        scope = try container.decode(String.self, forKey: .scope)
        // If issuedAt is not in the JSON (for tokens received from backend), use current time
        issuedAt = (try? container.decode(Date.self, forKey: .issuedAt)) ?? Date()
    }
    
    var expiryDate: Date {
        issuedAt.addingTimeInterval(TimeInterval(expiresIn))
    }
}
