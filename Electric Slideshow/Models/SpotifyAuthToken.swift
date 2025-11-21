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
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
    
    var expiryDate: Date {
        Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}
