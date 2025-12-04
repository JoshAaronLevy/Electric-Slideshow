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
    private var isHtmlLoading = false
    private var pendingAccessToken: String?
    private var deviceId: String?
    private var isPollingDevice = false

    init(player: InternalSpotifyPlayer, apiService: SpotifyAPIService) {
        self.player = player
        self.apiService = apiService

        self.player.onEvent = { [weak self] event in
            self?.handle(event: event)
        }
    }

    func initialize() {
        // Kick off HTML load
        if !isHtmlLoaded && !isHtmlLoading {
            isHtmlLoading = true
            player.load()
        }
        
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
            self.deviceId = event.deviceId
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
            player.ensureSDKReadyBridge()
            player.installDebugHooks()
            isHtmlLoaded = true
            isHtmlLoading = false
            if let token = pendingAccessToken {
                print("[SpotifyInternalPlaybackBackend] Flushing buffered token")
                player.setAccessToken(token)
                pendingAccessToken = nil
            }
            // Quick sanity probe of the JS environment to see why readiness might stall.
            player.evaluateJavaScript("""
            (() => {
              const hasSpotify = !!window.Spotify;
              const hasPlayerCtor = !!(window.Spotify && window.Spotify.Player);
              const hasInternal = !!window.INTERNAL_PLAYER;
              const hasPlayerInstance = !!(window.INTERNAL_PLAYER && window.INTERNAL_PLAYER._player);
              const sdkReadyFlag = !!(window.INTERNAL_PLAYER && window.INTERNAL_PLAYER._sdkReady);
              const tokenPresent = !!(window.INTERNAL_PLAYER && window.INTERNAL_PLAYER._accessToken);
              if (window.INTERNAL_PLAYER && typeof window.INTERNAL_PLAYER._maybeCreatePlayer === 'function') {
                window.INTERNAL_PLAYER._maybeCreatePlayer();
              }
              return { hasSpotify, hasPlayerCtor, hasInternal, hasPlayerInstance, sdkReadyFlag, tokenPresent };
            })();
            """)
            // Force a connect attempt after hooks are installed so we can log the result.
            player.evaluateJavaScript("""
            (() => {
              const p = window.INTERNAL_PLAYER && window.INTERNAL_PLAYER._player;
              if (!p || typeof p.connect !== 'function') { return 'no_player_for_connect'; }
              try {
                const pr = p.connect();
                if (pr && typeof pr.then === 'function') {
                  pr.then(ok => {
                    window.webkit?.messageHandlers?.playerEvent?.postMessage({ type: 'connectResult', message: ok ? 'connected' : 'failed' });
                  }).catch(err => {
                    window.webkit?.messageHandlers?.playerEvent?.postMessage({ type: 'error', code: 'connect_failed', message: String(err) });
                  });
                }
                return 'connect_invoked';
              } catch (err) {
                window.webkit?.messageHandlers?.playerEvent?.postMessage({ type: 'error', code: 'connect_throw', message: String(err) });
                return 'connect_threw';
              }
            })();
            """)

        case "tokenUpdated":
            print("[SpotifyInternalPlaybackBackend] Token updated in JS")
            startDevicePoll()

        case "notReady":
            print("[SpotifyInternalPlaybackBackend] Internal device offline: \(event.deviceId ?? "unknown")")
            if deviceId == event.deviceId {
                isReady = false
            }
            // Optional: could signal idle state here
            // onStateChanged?(.idle)

        case "connectResult":
            print("[SpotifyInternalPlaybackBackend] connectResult: \(event.message ?? "?")")
            if event.message == "connected" {
                startDevicePoll()
            }

        default:
            print("[SpotifyInternalPlaybackBackend] Unhandled event type: \(event.type)")
        }
    }

    // MARK: - MusicPlaybackBackend commands

    func playTrack(_ trackUri: String, startPositionMs: Int?, deviceId: String?) {
        let targetDeviceId = deviceId ?? self.deviceId

        guard isReady else {
            print("[SpotifyInternalPlaybackBackend] playTrack called but player not ready yet")
            onError?(.notReady)
            return
        }

        guard let targetDeviceId else {
            let message = "Internal player missing device id"
            print("[SpotifyInternalPlaybackBackend] \(message)")
            onError?(.backend(message: message))
            return
        }

        print("[SpotifyInternalPlaybackBackend] startPlayback on internal device \(targetDeviceId)")
        Task {
            do {
                try await apiService.startPlayback(
                    trackURIs: [trackUri],
                    deviceId: targetDeviceId,
                    startPositionMs: startPositionMs
                )
            } catch {
                let message = "Failed to start playback on internal player: \(error.localizedDescription)"
                print("[SpotifyInternalPlaybackBackend] \(message)")
                onError?(.backend(message: message))
            }
        }
    }

    func pause() {
        print("[SpotifyInternalPlaybackBackend] pause")
        player.pause()
    }

    func resume() {
        print("[SpotifyInternalPlaybackBackend] resume")
        Task {
            do {
                try await apiService.resumePlayback(deviceId: deviceId)
            } catch {
                print("[SpotifyInternalPlaybackBackend] Failed to resume via API: \(error.localizedDescription)")
                onError?(.backend(message: "Failed to resume internal player"))
            }
        }
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

    /// Polls Spotify devices to detect the internal player even if the JS ready event fails.
    private func startDevicePoll() {
        guard !isPollingDevice else { return }
        isPollingDevice = true

        Task {
            defer { isPollingDevice = false }

            for attempt in 1...6 {
                do {
                    let devices = try await apiService.fetchAvailableDevices()
                    if let internalDevice = devices.first(where: { $0.name == "Electric Slideshow Internal Player" }) {
                        deviceId = internalDevice.deviceId
                        isReady = true
                        print("[SpotifyInternalPlaybackBackend] Detected internal player device via API on attempt \(attempt): \(internalDevice.deviceId)")
                        return
                    }
                } catch {
                    print("[SpotifyInternalPlaybackBackend] Device poll failed (attempt \(attempt)): \(error.localizedDescription)")
                }

                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }

            print("[SpotifyInternalPlaybackBackend] Device poll: internal player not found after retries")
        }
    }
}
