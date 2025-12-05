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

    /// Global default mode for the app. Keep this `.externalDevice`
    /// until the internal player is fully implemented and tested.
    static let defaultMode: PlaybackBackendMode = .internalWebPlayer

    /// Cached internal backend so we can reuse the same instance.
    private static var sharedInternalBackend: SpotifyInternalPlaybackBackend?
    
    /// Shared InternalPlayerManager instance
    private static var sharedPlayerManager: InternalPlayerManager?

    /// Creates a music playback backend for the given mode.
    ///
    /// - Parameters:
    ///   - mode: Which backend mode to use. Defaults to `defaultMode`.
    ///   - spotifyAPIService: Your existing SpotifyAPIService instance.
    ///   - spotifyAuthService: Your existing SpotifyAuthService instance.
    /// - Returns: A `MusicPlaybackBackend` or `nil` if it cannot be created.
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
            // Existing behavior: control a Spotify device via Web API.
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
        backend.initialize()
        return backend
    }
}
