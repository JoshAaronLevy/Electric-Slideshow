//
//  SpotifyConfig.swift
//  Electric Slideshow
//
//  Created by GitHub Copilot on 11/21/25.
//

import Foundation

struct SpotifyConfig {
    static let clientId = "a5420653f68e4295b5a8fbca7b98cd3a"
    static let redirectURI = "com.electricslideshow://callback"
    static let tokenExchangeURL = URL(string: "https://electric-slideshow-server.onrender.com/auth/spotify/token")!
    static let tokenRefreshURL = URL(string: "https://electric-slideshow-server.onrender.com/auth/spotify/refresh")!
    static let internalPlayerURL = URL(string: "https://electric-slideshow-server.onrender.com/internal-player")!
    
    static let scopes = [
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-library-read",
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-playback-position"
    ]
    
    static let spotifyAuthURL = URL(string: "https://accounts.spotify.com/authorize")!
    static let spotifyAPIBaseURL = URL(string: "https://api.spotify.com/v1")!
}
