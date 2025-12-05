//
//  PlaybackBackendFactory.swift
//  Electric Slideshow
//
//  Central place to decide which music playback backend to use
//  (external Spotify device vs Electron-based internal player).
//

import Foundation

/// Which playback backend Electric Slideshow should use.
enum PlaybackBackendMode {
    /// Use the existing external device control via Spotify Web API.
    case externalDevice

    /// Use the Electron-based internal player managed by InternalPlayerManager.
    case internalWebPlayer
}

struct PlaybackBackendFactory {
    static let defaultMode: PlaybackBackendMode = .internalWebPlayer

    /// Cached internal backend so we can reuse the same instance.
    private static var sharedInternalBackend: SpotifyInternalPlaybackBackend?
    
    /// Shared InternalPlayerManager instance
    private static var sharedPlayerManager: InternalPlayerManager?

    static func makeBackend(
        mode: PlaybackBackendMode = defaultMode,
        spotifyAPIService: SpotifyAPIService?,
        spotifyAuthService: SpotifyAuthService = .shared
    ) -> MusicPlaybackBackend? {
        guard let apiService = spotifyAPIService else {
            // No Spotify service → no backend.
            return nil
        }

        switch mode {
        case .externalDevice:
            return SpotifyExternalPlaybackBackend(apiService: apiService)

        case .internalWebPlayer:
            // Electron-based internal player managed by InternalPlayerManager.
            if let cached = sharedInternalBackend {
                return cached
            }
            
            // Create or reuse the player manager
            let playerManager = sharedPlayerManager ?? InternalPlayerManager()
            sharedPlayerManager = playerManager
            
            let backend = SpotifyInternalPlaybackBackend(
                playerManager: playerManager,
                apiService: apiService,
                authService: spotifyAuthService
            )
            sharedInternalBackend = backend
            return backend
        }
    }

    /// Pre-warm the internal player so it can be ready before a slideshow starts.
    /// This starts the Electron process with a valid Spotify token.
    @discardableResult
    static func prewarmInternalBackend(
        spotifyAPIService: SpotifyAPIService?,
        spotifyAuthService: SpotifyAuthService = .shared
    ) -> MusicPlaybackBackend? {
        guard let apiService = spotifyAPIService else { return nil }
        
        if let cached = sharedInternalBackend {
            print("[PlaybackBackendFactory] Reusing cached internal backend instance")
            PlayerInitLogger.shared.log(
                "Reusing cached internal backend instance",
                source: "PlaybackBackendFactory"
            )
            return cached
        }
        
        print("[PlaybackBackendFactory] Creating new internal backend instance")
        PlayerInitLogger.shared.log(
            "Creating new internal backend instance",
            source: "PlaybackBackendFactory"
        )
        
        // Create or reuse the player manager
        let playerManager = sharedPlayerManager ?? InternalPlayerManager()
        sharedPlayerManager = playerManager
        
        let backend = SpotifyInternalPlaybackBackend(
            playerManager: playerManager,
            apiService: apiService,
            authService: spotifyAuthService
        )
        sharedInternalBackend = backend
        backend.initialize()
        return backend
    }
}
