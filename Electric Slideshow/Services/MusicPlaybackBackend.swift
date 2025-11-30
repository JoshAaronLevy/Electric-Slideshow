//
//  MusicPlaybackBackend.swift
//  Electric Slideshow
//
//  A backend-agnostic interface for controlling music playback.
//  Implementations:
//  - SpotifyExternalPlaybackBackend (current Node/Spotify device control)
//  - SpotifyInternalPlaybackBackend (future Web Playback SDK in WKWebView)
//

import Foundation

/// The normalized playback state that the rest of the app consumes,
/// regardless of how/where the music is actually played.
struct PlaybackState: Equatable {
    /// Spotify track URI or other backend-specific identifier (optional).
    let trackUri: String?

    /// Human-readable info for the UI.
    let trackName: String?
    let artistName: String?

    /// Current playback position in milliseconds.
    let positionMs: Int

    /// Total track duration in milliseconds.
    let durationMs: Int

    /// Whether audio is currently playing (not paused).
    let isPlaying: Bool

    /// True while the backend is buffering / starting playback.
    let isBuffering: Bool

    /// Convenience: an "idle" state with no active track.
    static var idle: PlaybackState {
        PlaybackState(
            trackUri: nil,
            trackName: nil,
            artistName: nil,
            positionMs: 0,
            durationMs: 0,
            isPlaying: false,
            isBuffering: false
        )
    }
}

/// High-level errors that playback backends can surface.
/// Implementations can wrap more detailed error info if needed.
enum PlaybackError: Error {
    case notReady               // Backend not initialized yet
    case unauthorized           // Missing / invalid token / auth
    case network                // Network-level failure
    case backend(message: String)  // Backend-specific / SDK error
}

/// Common interface for anything that can play music for Electric Slideshow.
/// The slideshow engine talks ONLY to this, never directly to Spotify APIs.
///
/// Implementations should be reference types (class) so they can manage
/// internal state and resources.
protocol MusicPlaybackBackend: AnyObject {

    /// Called by the slideshow engine / UI layer to be notified
    /// whenever playback state changes.
    ///
    /// Implementations should invoke this on the main queue when
    /// state changes affect UI.
    var onStateChanged: ((PlaybackState) -> Void)? { get set }

    /// Called when an error occurs that the caller might want to surface
    /// or react to (e.g. falling back to a different backend).
    var onError: ((PlaybackError) -> Void)? { get set }

    /// Indicates whether this backend is fully initialized and ready
    /// to accept playback commands.
    var isReady: Bool { get }

    /// Called once after creation to allow the backend to perform any
    /// setup work (token fetch, SDK init, etc.).
    ///
    /// Implementations may call `onError` if setup fails.
    func initialize()

    // MARK: - Core playback commands

    /// Start playing the given track.
    ///
    /// - Parameters:
    ///   - trackUri: Backend-specific track identifier (e.g. a Spotify URI).
    ///   - startPositionMs: Optional start offset in milliseconds.
    func playTrack(_ trackUri: String, startPositionMs: Int?)

    /// Pause playback, if a track is currently playing.
    func pause()

    /// Resume playback, if a track is loaded but paused.
    func resume()

    /// Skip to the next track in the current context (playlist, queue, etc.).
    func nextTrack()

    /// Skip to the previous track in the current context.
    func previousTrack()

    /// Seek to a position within the current track (in milliseconds).
    func seek(to positionMs: Int)

    /// Adjust playback volume (0.0–1.0).
    ///
    /// Implementations that cannot control volume may either ignore
    /// this call or surface an appropriate `PlaybackError`.
    func setVolume(_ value: Double)
}

/// A simple no-op backend that does nothing. Useful for previews or
/// as a placeholder before a real backend is injected.
final class NoopPlaybackBackend: MusicPlaybackBackend {

    var onStateChanged: ((PlaybackState) -> Void)?
    var onError: ((PlaybackError) -> Void)?

    private(set) var isReady: Bool = true

    func initialize() {
        // No-op
        onStateChanged?(.idle)
    }

    func playTrack(_ trackUri: String, startPositionMs: Int?) {
        // No-op
        onStateChanged?(.idle)
    }

    func pause() { }
    func resume() { }
    func nextTrack() { }
    func previousTrack() { }
    func seek(to positionMs: Int) { }
    func setVolume(_ value: Double) { }
}
