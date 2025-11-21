//
//  SpotifyConfig.swift
//  Electric Slideshow
//
//  Created by GitHub Copilot on 11/21/25.
//

import Foundation

struct SpotifyConfig {
    static let clientId = "485cef747f614337b334513a7b9a7322"
    static let redirectURI = "com.slideshowbuddy://callback"
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
