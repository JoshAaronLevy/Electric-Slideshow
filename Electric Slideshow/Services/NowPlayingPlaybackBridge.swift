import Foundation
import Combine

/// A lightweight bridge that lets other views (e.g. the Now Playing bottom bar)
/// send playback commands to the active slideshow without needing to know about
/// the concrete playback view model.
@MainActor
final class NowPlayingPlaybackBridge: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    // Slideshow navigation
    var goToPreviousSlide: (() -> Void)?
    var togglePlayPause: (() -> Void)?
    var goToNextSlide: (() -> Void)?
}
