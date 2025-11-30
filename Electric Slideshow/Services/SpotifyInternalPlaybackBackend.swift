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

    init(player: InternalSpotifyPlayer = InternalSpotifyPlayer()) {
        self.player = player

        // Wire player events into our callbacks.
        self.player.onEvent = { [weak self] event in
            self?.handlePlayerEvent(event)
        }
    }

    func initialize() {
        // For now, just load the skeleton HTML. Once the JS bridge calls
        // back with a "ready" event, we'll mark isReady = true.
        player.load()
    }

    func playTrack(_ trackUri: String, startPositionMs: Int?) {
        // Not yet implemented – we'll wire this to JS later.
        debugPrint("[SpotifyInternalPlaybackBackend] playTrack(uri: \(trackUri), startPositionMs: \(startPositionMs ?? 0)) – not implemented yet")
    }

    func pause() {
        debugPrint("[SpotifyInternalPlaybackBackend] pause() – not implemented yet")
    }

    func resume() {
        debugPrint("[SpotifyInternalPlaybackBackend] resume() – not implemented yet")
    }

    func nextTrack() {
        debugPrint("[SpotifyInternalPlaybackBackend] nextTrack() – not implemented yet")
    }

    func previousTrack() {
        debugPrint("[SpotifyInternalPlaybackBackend] previousTrack() – not implemented yet")
    }

    func seek(to positionMs: Int) {
        debugPrint("[SpotifyInternalPlaybackBackend] seek(to: \(positionMs)) – not implemented yet")
    }

    func setVolume(_ value: Double) {
        debugPrint("[SpotifyInternalPlaybackBackend] setVolume(\(value)) – not implemented yet")
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
