import Foundation

/// Controls how long each music track should play while a slideshow is running.
enum MusicClipMode: String, CaseIterable, Identifiable {
    case seconds30
    case seconds45
    case seconds60
    case fullSong

    var id: String { rawValue }

    /// User-facing label for the picker.
    var displayName: String {
        switch self {
        case .seconds30: return "30 seconds"
        case .seconds45: return "45 seconds"
        case .seconds60: return "60 seconds"
        case .fullSong:  return "Full song"
        }
    }

    /// Duration in seconds for the clip.
    /// `nil` means "do not clip" (play the full song).
    var clipDuration: TimeInterval? {
        switch self {
        case .seconds30: return 30
        case .seconds45: return 45
        case .seconds60: return 60
        case .fullSong:  return nil
        }
    }
}
