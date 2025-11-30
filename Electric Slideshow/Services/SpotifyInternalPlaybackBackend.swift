//
//  SpotifyInternalPlaybackBackend.swift
//  Electric Slideshow
//
//  Skeleton implementation of MusicPlaybackBackend that will
//  eventually drive the Spotify Web Playback SDK inside
//  InternalSpotifyPlayer. For now it just wires up the JS bridge
//  and logs events.
//

import Foundation

final class SpotifyInternalPlaybackBackend: MusicPlaybackBackend {

    // MARK: - MusicPlaybackBackend

    var onStateChanged: ((PlaybackState) -> Void)?
    var onError: ((PlaybackError) -> Void)?

    private(set) var isReady: Bool = false

    private let player: InternalSpotifyPlayer
    private let apiService: SpotifyAPIService

    init(player: InternalSpotifyPlayer, apiService: SpotifyAPIService) {
        self.player = player
        self.apiService = apiService

        self.player.onEvent = { [weak self] event in
            self?.handle(event: event)
        }
    }

    func initialize() {
        // Kick off HTML load
        player.load()
        
        // Fetch web playback token asynchronously
        Task { @MainActor in
            do {
                let token = try await apiService.getWebPlaybackAccessToken()
                player.setAccessToken(token)
            } catch {
                let message = "Failed to get web playback token: \(error.localizedDescription)"
                print("[SpotifyInternalPlaybackBackend] \(message)")
                onError?(.backend(message: message))
            }
        }
    }

    // MARK: - Event handling

    private func handle(event: InternalPlayerEvent) {
        switch event.type {
        case "ready":
            print("[SpotifyInternalPlaybackBackend] Internal player ready, deviceId=\(event.deviceId ?? "unknown")")
            isReady = true

        case "stateChanged":
            guard
                let isPlaying = event.isPlaying,
                let positionMs = event.positionMs,
                let durationMs = event.durationMs
            else {
                return
            }

            let state = PlaybackState(
                trackUri: event.trackUri,
                trackName: event.trackName,
                artistName: event.artistName,
                positionMs: positionMs,
                durationMs: durationMs,
                isPlaying: isPlaying,
                isBuffering: false
            )

            // Push into the rest of the app (SlideshowPlaybackViewModel, NowPlaying, etc.)
            onStateChanged?(state)

        case "error":
            let message = event.message ?? "Unknown internal player error"
            print("[SpotifyInternalPlaybackBackend] error: \(event.code ?? "?") - \(message)")
            onError?(.backend(message: message))

        case "htmlLoaded", "tokenUpdated":
            print("[SpotifyInternalPlaybackBackend] event: \(event.type)")

        case "notReady":
            print("[SpotifyInternalPlaybackBackend] Internal device offline: \(event.deviceId ?? "unknown")")
            // You could emit an idle/paused state here if you want:
            // onStateChanged?(.idle)

        default:
            print("[SpotifyInternalPlaybackBackend] Unhandled event type: \(event.type)")
        }
    }

    // MARK: - MusicPlaybackBackend commands

    func playTrack(_ trackUri: String, startPositionMs: Int?) {
        // For now, just resume whatever context the Web Playback SDK has.
        // Later we'll wire trackUri + context properly.
        player.play()
    }

    func pause() {
        player.pause()
    }

    func resume() {
        player.play()
    }

    func nextTrack() {
        player.nextTrack()
    }

    func previousTrack() {
        player.previousTrack()
    }

    func seek(to positionMs: Int) {
        player.seek(to: positionMs)
    }

    func setVolume(_ value: Double) {
        player.setVolume(value)
    }

    func setShuffleEnabled(_ isOn: Bool) {
        // We'll handle shuffle via the Web API or SDK later.
        print("[SpotifyInternalPlaybackBackend] setShuffleEnabled(\(isOn)) – not wired yet")
    }

    func setRepeatMode(_ mode: PlaybackRepeatMode) {
        print("[SpotifyInternalPlaybackBackend] setRepeatMode(\(mode)) – not wired yet")
    }
}
