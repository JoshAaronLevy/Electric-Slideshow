//
//  SpotifyInternalPlaybackBackend.swift
//  Electric Slideshow
//
//  Implementation of MusicPlaybackBackend that uses the Electron-based
//  internal player managed by InternalPlayerManager. This backend starts
//  the Electron process and controls playback via Spotify Web API.
//

import Foundation

final class SpotifyInternalPlaybackBackend: MusicPlaybackBackend {

    // MARK: - MusicPlaybackBackend

    var onStateChanged: ((PlaybackState) -> Void)?
    var onError: ((PlaybackError) -> Void)?

    private(set) var isReady: Bool = false
    var requiresExternalApp: Bool { false }

    private let playerManager: InternalPlayerManager
    private let apiService: SpotifyAPIService
    private let authService: SpotifyAuthService

    private var deviceId: String?
    private var isPollingDevice = false

    init(playerManager: InternalPlayerManager, apiService: SpotifyAPIService, authService: SpotifyAuthService) {
        self.playerManager = playerManager
        self.apiService = apiService
        self.authService = authService
    }

    func initialize() {
        print("[SpotifyInternalPlaybackBackend] Initializing - starting Electron player process")
        
        Task { @MainActor in
            do {
                // Get valid access token
                let token = try await authService.getValidAccessToken()
                
                // Start the Electron process with the token
                try playerManager.start(withAccessToken: token)
                
                print("[SpotifyInternalPlaybackBackend] Electron process started, polling for device")
                
                // Poll for the device to appear in Spotify's device list
                startDevicePoll()
            } catch {
                let message = "Failed to start internal player: \(error.localizedDescription)"
                print("[SpotifyInternalPlaybackBackend] \(message)")
                onError?(.backend(message: message))
            }
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
        Task {
            do {
                try await apiService.pausePlayback(deviceId: deviceId)
            } catch {
                print("[SpotifyInternalPlaybackBackend] Failed to pause: \(error.localizedDescription)")
                onError?(.backend(message: "Failed to pause internal player"))
            }
        }
    }

    func resume() {
        print("[SpotifyInternalPlaybackBackend] resume")
        Task {
            do {
                try await apiService.resumePlayback(deviceId: deviceId)
            } catch {
                print("[SpotifyInternalPlaybackBackend] Failed to resume: \(error.localizedDescription)")
                onError?(.backend(message: "Failed to resume internal player"))
            }
        }
    }

    func nextTrack() {
        print("[SpotifyInternalPlaybackBackend] nextTrack")
        Task {
            do {
                try await apiService.skipToNext(deviceId: deviceId)
            } catch {
                print("[SpotifyInternalPlaybackBackend] Failed to skip to next: \(error.localizedDescription)")
                onError?(.backend(message: "Failed to skip to next track"))
            }
        }
    }

    func previousTrack() {
        print("[SpotifyInternalPlaybackBackend] previousTrack")
        Task {
            do {
                try await apiService.skipToPrevious(deviceId: deviceId)
            } catch {
                print("[SpotifyInternalPlaybackBackend] Failed to skip to previous: \(error.localizedDescription)")
                onError?(.backend(message: "Failed to skip to previous track"))
            }
        }
    }

    func seek(to positionMs: Int) {
        print("[SpotifyInternalPlaybackBackend] seek(to: \(positionMs))")
        Task {
            do {
                try await apiService.seek(to: positionMs, deviceId: deviceId)
            } catch {
                print("[SpotifyInternalPlaybackBackend] Failed to seek: \(error.localizedDescription)")
                onError?(.backend(message: "Failed to seek"))
            }
        }
    }

    func setVolume(_ value: Double) {
        print("[SpotifyInternalPlaybackBackend] setVolume(\(value))")
        Task {
            do {
                let volumePercent = Int(value * 100)
                try await apiService.setVolume(volumePercent, deviceId: deviceId)
            } catch {
                print("[SpotifyInternalPlaybackBackend] Failed to set volume: \(error.localizedDescription)")
                onError?(.backend(message: "Failed to set volume"))
            }
        }
    }

    func setShuffleEnabled(_ isOn: Bool) {
        print("[SpotifyInternalPlaybackBackend] setShuffleEnabled(\(isOn)) – not wired yet")
    }

    func setRepeatMode(_ mode: PlaybackRepeatMode) {
        print("[SpotifyInternalPlaybackBackend] setRepeatMode(\(mode)) – not wired yet")
    }

    // MARK: - Private Helpers
    
    /// Polls Spotify devices to detect the internal player after it launches
    private func startDevicePoll() {
        guard !isPollingDevice else { return }
        isPollingDevice = true

        Task {
            defer { isPollingDevice = false }

            for attempt in 1...10 {
                do {
                    let devices = try await apiService.fetchAvailableDevices()
                    if let internalDevice = devices.first(where: { $0.name == "Electric Slideshow Internal Player" }) {
                        deviceId = internalDevice.deviceId
                        isReady = true
                        print("[SpotifyInternalPlaybackBackend] Detected internal player device on attempt \(attempt): \(internalDevice.deviceId)")
                        return
                    }
                } catch {
                    print("[SpotifyInternalPlaybackBackend] Device poll failed (attempt \(attempt)): \(error.localizedDescription)")
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s between attempts
            }

            print("[SpotifyInternalPlaybackBackend] Device poll: internal player not found after 10 attempts")
            onError?(.backend(message: "Internal player device not detected. Make sure the Electron process is running."))
        }
    }
}
