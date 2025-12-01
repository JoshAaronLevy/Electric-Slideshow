//
//  SpotifyExternalPlaybackBackend.swift
//  Electric Slideshow
//
//  Adapts SpotifyAPIService into the MusicPlaybackBackend interface.
//  For now, this is just a thin command layer (play/pause/next/previous/seek).
//  We keep your existing polling + clip logic in SlideshowPlaybackViewModel.
//

import Foundation

final class SpotifyExternalPlaybackBackend: MusicPlaybackBackend {

    // MARK: - MusicPlaybackBackend

    var onStateChanged: ((PlaybackState) -> Void)?
    var onError: ((PlaybackError) -> Void)?

    private(set) var isReady: Bool = false
    var requiresExternalApp: Bool { true }

    // MARK: - Dependencies

    private let apiService: SpotifyAPIService

    init(apiService: SpotifyAPIService) {
        self.apiService = apiService
    }

    func initialize() {
        // For the external backend we don't need heavy setup.
        // Mark as ready so callers know they can send commands.
        isReady = true
    }

    func playTrack(_ trackUri: String, startPositionMs: Int?) {
        // For your current flow you usually start a playlist via startPlayback(trackURIs:),
        // so we don't use this yet. We can wire it later if/when you want
        // track-level control through the backend.
        //
        // Keeping a debug log so we know if something accidentally calls it.
        debugPrint("[SpotifyExternalPlaybackBackend] playTrack(uri: \(trackUri), startPositionMs: \(startPositionMs ?? 0)) – not wired yet")
    }

    func pause() {
        Task {
            do {
                try await apiService.pausePlayback()
            } catch {
                self.onError?(.backend(message: "Failed to pause playback: \(error.localizedDescription)"))
            }
        }
    }

    func resume() {
        Task {
            do {
                // resumePlayback() with no deviceId resumes the current context.
                try await apiService.resumePlayback()
            } catch {
                self.onError?(.backend(message: "Failed to resume playback: \(error.localizedDescription)"))
            }
        }
    }

    func nextTrack() {
        Task {
            do {
                try await apiService.skipToNext()
            } catch {
                self.onError?(.backend(message: "Failed to skip to next track: \(error.localizedDescription)"))
            }
        }
    }

    func previousTrack() {
        Task {
            do {
                try await apiService.skipToPrevious()
            } catch {
                self.onError?(.backend(message: "Failed to skip to previous track: \(error.localizedDescription)"))
            }
        }
    }

    func seek(to positionMs: Int) {
        Task {
            do {
                try await apiService.seekToPosition(positionMs: positionMs)
            } catch {
                self.onError?(.backend(message: "Failed to seek: \(error.localizedDescription)"))
            }
        }
    }

    func setVolume(_ value: Double) {
        // You don't have volume APIs wired yet, so we simply ignore this for now.
        debugPrint("[SpotifyExternalPlaybackBackend] setVolume(\(value)) – not implemented")
    }

    func setShuffleEnabled(_ isOn: Bool) {
        Task {
            do {
                try await apiService.setShuffle(isOn: isOn)
            } catch {
                self.onError?(.backend(message: "Failed to set shuffle: \(error.localizedDescription)"))
            }
        }
    }

    func setRepeatMode(_ mode: PlaybackRepeatMode) {
        Task {
            do {
                try await apiService.setRepeat(mode: mode)
            } catch {
                self.onError?(.backend(message: "Failed to set repeat mode: \(error.localizedDescription)"))
            }
        }
    }
}
