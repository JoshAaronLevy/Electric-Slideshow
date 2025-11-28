import Foundation
import Combine

/// A lightweight bridge that lets other views (e.g. the Now Playing UI)
/// both SEND playback commands and OBSERVE a small subset of playback state
/// without knowing about the concrete playback view model.
@MainActor
final class NowPlayingPlaybackBridge: ObservableObject {

    // MARK: - Commands (write-only from UI)

    // Slideshow navigation
    var goToPreviousSlide: (() -> Void)?
    var togglePlayPause: (() -> Void)?
    var goToNextSlide: (() -> Void)?

    // Music-only controls (should NOT affect slideshow timer / slides)
    var musicPreviousTrack: (() -> Void)?
    var musicTogglePlayPause: (() -> Void)?
    var musicNextTrack: (() -> Void)?

    // MARK: - Mode / configuration callbacks

    /// Called when the user changes the music clip mode in the UI.
    var onClipModeChanged: ((MusicClipMode) -> Void)?

    // MARK: - Read-only state for UI

    /// Zero-based index of the current slide.
    @Published var currentSlideIndex: Int = 0

    /// Total number of slides in the current slideshow.
    @Published var totalSlides: Int = 0

    /// Whether the slideshow timer is currently playing.
    @Published var isSlideshowPlaying: Bool = false

    /// Current Spotify track title (if any).
    @Published var currentTrackTitle: String = ""

    /// Current Spotify track primary artist (if any).
    @Published var currentTrackArtist: String = ""

    /// Whether Spotify is currently playing.
    @Published var isMusicPlaying: Bool = false

    // MARK: - Playback configuration

    /// Currently selected clip mode for music playback in Now Playing.
    @Published var clipMode: MusicClipMode = .seconds30
}
