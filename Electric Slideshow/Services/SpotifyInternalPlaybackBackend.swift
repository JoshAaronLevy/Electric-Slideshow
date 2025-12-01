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
    var requiresExternalApp: Bool { false }

    private let player: InternalSpotifyPlayer
    private let apiService: SpotifyAPIService

    private var isHtmlLoaded = false
    private var pendingAccessToken: String?

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
                self.applyAccessToken(token)
            } catch {
                let message = "Failed to get web playback token: \(error.localizedDescription)"
                print("[SpotifyInternalPlaybackBackend] \(message)")
                onError?(.backend(message: message))
            }
        }
    }
    
    private func applyAccessToken(_ token: String) {
        if isHtmlLoaded {
            player.setAccessToken(token)
        } else {
            print("[SpotifyInternalPlaybackBackend] HTML not loaded yet, buffering token")
            pendingAccessToken = token
        }
    }

    // MARK: - Event handling

    private func handle(event: InternalPlayerEvent) {
        switch event.type {
        case "ready":
            let deviceId = event.deviceId ?? "unknown"
            print("[SpotifyInternalPlaybackBackend] Internal player ready, deviceId=\(deviceId)")
            isReady = true

        case "stateChanged":
            // Even if some fields are missing, we try to construct a valid state.
            // The JS side usually sends null for missing tracks, so we handle that.
            let isPlaying = event.isPlaying ?? false
            let positionMs = event.positionMs ?? 0
            let durationMs = event.durationMs ?? 0
            
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
            let code = event.code ?? "?"
            print("[SpotifyInternalPlaybackBackend] error: \(code) - \(message)")
            onError?(.backend(message: "Internal Player Error: \(message)"))

        case "htmlLoaded":
            print("[SpotifyInternalPlaybackBackend] HTML loaded successfully")
            isHtmlLoaded = true
            if let token = pendingAccessToken {
                print("[SpotifyInternalPlaybackBackend] Flushing buffered token")
                player.setAccessToken(token)
                pendingAccessToken = nil
            }

        case "tokenUpdated":
            print("[SpotifyInternalPlaybackBackend] Token updated in JS")

        case "notReady":
            print("[SpotifyInternalPlaybackBackend] Internal device offline: \(event.deviceId ?? "unknown")")
            // Optional: could signal idle state here
            // onStateChanged?(.idle)

        default:
            print("[SpotifyInternalPlaybackBackend] Unhandled event type: \(event.type)")
        }
    }

    // MARK: - MusicPlaybackBackend commands

    func playTrack(_ trackUri: String, startPositionMs: Int?) {
        // Log intent but ignore args for now as requested
        print("[SpotifyInternalPlaybackBackend] playTrack requested for \(trackUri) (pos: \(startPositionMs ?? 0)ms). Resuming existing context.")
        player.play()
    }

    func pause() {
        print("[SpotifyInternalPlaybackBackend] pause")
        player.pause()
    }

    func resume() {
        print("[SpotifyInternalPlaybackBackend] resume")
        player.play()
    }

    func nextTrack() {
        print("[SpotifyInternalPlaybackBackend] nextTrack")
        player.nextTrack()
    }

    func previousTrack() {
        print("[SpotifyInternalPlaybackBackend] previousTrack")
        player.previousTrack()
    }

    func seek(to positionMs: Int) {
        print("[SpotifyInternalPlaybackBackend] seek(to: \(positionMs))")
        player.seek(to: positionMs)
    }

    func setVolume(_ value: Double) {
        print("[SpotifyInternalPlaybackBackend] setVolume(\(value))")
        player.setVolume(value)
    }

    func setShuffleEnabled(_ isOn: Bool) {
        print("[SpotifyInternalPlaybackBackend] setShuffleEnabled(\(isOn)) – not wired yet")
    }

    func setRepeatMode(_ mode: PlaybackRepeatMode) {
        print("[SpotifyInternalPlaybackBackend] setRepeatMode(\(mode)) – not wired yet")
    }
}
