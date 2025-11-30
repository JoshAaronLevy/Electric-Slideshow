//
//  PlaybackBackendFactory.swift
//  Electric Slideshow
//
//  Central place to decide which music playback backend to use
//  (external Spotify device vs internal web player).
//

import Foundation

/// Which playback backend Electric Slideshow should use.
enum PlaybackBackendMode {
    /// Use the existing external device control via Spotify Web API.
    case externalDevice

    /// Use the internal web player (Spotify Web Playback SDK inside WKWebView).
    /// NOTE: currently still experimental / skeleton.
    case internalWebPlayer
}

struct PlaybackBackendFactory {

    /// Global default mode for the app. Keep this `.externalDevice`
    /// until the internal player is fully implemented and tested.
    static let defaultMode: PlaybackBackendMode = .externalDevice

    /// Creates a music playback backend for the given mode.
    ///
    /// - Parameters:
    ///   - mode: Which backend mode to use. Defaults to `defaultMode`.
    ///   - spotifyAPIService: Your existing SpotifyAPIService instance.
    /// - Returns: A `MusicPlaybackBackend` or `nil` if it cannot be created.
    static func makeBackend(
        mode: PlaybackBackendMode = defaultMode,
        spotifyAPIService: SpotifyAPIService?
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
            // Experimental: internal web player.
            // For now this is just a skeleton; commands are logged but not executed.
            return SpotifyInternalPlaybackBackend()
        }
    }
}
