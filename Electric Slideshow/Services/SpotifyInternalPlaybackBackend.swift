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

    // MARK: - Dependencies

    private let player: InternalSpotifyPlayer

    private let apiService: SpotifyAPIService

    init(
        apiService: SpotifyAPIService,
        player: InternalSpotifyPlayer = InternalSpotifyPlayer()
    ) {
        self.apiService = apiService
        self.player = player

        // Wire player events into our callbacks.
        self.player.onEvent = { [weak self] event in
            self?.handlePlayerEvent(event)
        }
    }

    func initialize() {
        // Load the skeleton HTML / JS bridge.
        player.load()

        // Fetch a Web Playback-capable token and inject it into JS.
        Task {
            do {
                let token = try await apiService.getWebPlaybackAccessToken()
                await MainActor.run {
                    self.player.setAccessToken(token)
                }
            } catch {
                await MainActor.run {
                    self.onError?(.backend(message: "Failed to fetch Web Playback token: \(error.localizedDescription)"))
                }
            }
        }
    }

    func playTrack(_ trackUri: String, startPositionMs: Int?) {
        // For now we just call play() – later we'll wire trackUri + seek.
        debugPrint("[SpotifyInternalPlaybackBackend] playTrack(uri: \(trackUri), startPositionMs: \(startPositionMs ?? 0))")
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

    // MARK: - Private helpers

    private func handlePlayerEvent(_ event: InternalPlayerEvent) {
        switch event.type {
        case .ready:
            isReady = true
            print("[SpotifyInternalPlaybackBackend] Internal player ready: \(event.message ?? "")")

            // Emit an initial idle state to anyone listening.
            onStateChanged?(.idle)

        case .stateChanged:
            // Once the JS side sends real playback state, this is where
            // we'll map it into PlaybackState and call onStateChanged.
            print("[SpotifyInternalPlaybackBackend] stateChanged: \(event.message ?? "")")

        case .error:
            print("[SpotifyInternalPlaybackBackend] error: \(event.message ?? "")")
            onError?(.backend(message: event.message ?? "Internal player error"))
        }
    }

    func setShuffleEnabled(_ isOn: Bool) {
        debugPrint("[SpotifyInternalPlaybackBackend] setShuffleEnabled(\(isOn)) – not implemented yet")
    }

    func setRepeatMode(_ mode: PlaybackRepeatMode) {
        debugPrint("[SpotifyInternalPlaybackBackend] setRepeatMode(\(mode)) – not implemented yet")
    }
}
