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
    var onReady: (() -> Void)?

    private(set) var isReady: Bool = false
    var requiresExternalApp: Bool { false }

    private let playerManager: InternalPlayerManager
    private let apiService: SpotifyAPIService
    private let authService: SpotifyAuthService

    private var deviceId: String?
    private var isPollingDevice = false
    private var isInitializing = false
    private var hasNotifiedReady = false
    private let internalDeviceName = "Electric Slideshow Internal Player"

    init(playerManager: InternalPlayerManager, apiService: SpotifyAPIService, authService: SpotifyAuthService) {
        self.playerManager = playerManager
        self.apiService = apiService
        self.authService = authService
    }

    func initialize() {
        guard !isInitializing else {
            print("[SpotifyInternalPlaybackBackend] initialize called while already initializing; ignoring duplicate call")
            return
        }
        isInitializing = true
        
        let backendBaseURL = SpotifyConfig.backendBaseURL
        print("[SpotifyInternalPlaybackBackend] Initializing internal backend, booting internal player (backend base: \(backendBaseURL.absoluteString))")
        PlayerInitLogger.shared.log(
            "Initializing internal backend, booting internal player (backend base: \(backendBaseURL.absoluteString))",
            source: "SpotifyInternalPlaybackBackend"
        )
        
        Task { @MainActor in
            defer { isInitializing = false }
            do {
                // Get valid access token
                let token = try await authService.getValidAccessToken()
                
                // Start or reuse the Electron process with the token
                try playerManager.ensureInternalPlayerRunning(accessToken: token, backendBaseURL: backendBaseURL)
                
                if isReady, let deviceId {
                    print("[SpotifyInternalPlaybackBackend] Internal backend already ready with device id \(deviceId); reusing existing session")
                    PlayerInitLogger.shared.log(
                        "Internal backend already ready with device id \(deviceId); reusing existing session",
                        source: "SpotifyInternalPlaybackBackend"
                    )
                    return
                }
                
                // Reset state before polling
                deviceId = nil
                isReady = false
                hasNotifiedReady = false
                
                print("[SpotifyInternalPlaybackBackend] Electron process started, polling for device")
                PlayerInitLogger.shared.log(
                    "Electron process started, polling for device",
                    source: "SpotifyInternalPlaybackBackend"
                )
                
                // Poll for the device to appear in Spotify's device list
                startDevicePoll()
            } catch {
                let message = "Failed to start internal player: \(error.localizedDescription)"
                print("[SpotifyInternalPlaybackBackend] \(message)")
                PlayerInitLogger.shared.log(
                    message,
                    source: "SpotifyInternalPlaybackBackend"
                )
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
        
        let maxAttempts = 30

        Task {
            defer { isPollingDevice = false }

            for attempt in 1...maxAttempts {
                do {
                    let devices = try await apiService.fetchAvailableDevices()
                    if let internalDevice = devices.first(where: { $0.name == internalDeviceName }) {
                        deviceId = internalDevice.deviceId
                        isReady = true
                        if !hasNotifiedReady {
                            hasNotifiedReady = true
                            onReady?()
                        }
                        print("[SpotifyInternalPlaybackBackend] Detected internal player device on attempt \(attempt): id=\(internalDevice.deviceId), type=\(internalDevice.type), active=\(internalDevice.is_active), volume=\(internalDevice.volume_percent ?? 0)%")
                        PlayerInitLogger.shared.log(
                            "Detected internal player device on attempt \(attempt): id=\(internalDevice.deviceId), type=\(internalDevice.type), active=\(internalDevice.is_active), volume=\(internalDevice.volume_percent ?? 0)%",
                            source: "SpotifyInternalPlaybackBackend"
                        )
                        return
                    }
                    
                    if attempt == 1 || attempt % 5 == 0 {
                        print("[SpotifyInternalPlaybackBackend] Internal player not in device list yet (attempt \(attempt)/\(maxAttempts))")
                        PlayerInitLogger.shared.log(
                            "Internal player not in device list yet (attempt \(attempt)/\(maxAttempts))",
                            source: "SpotifyInternalPlaybackBackend"
                        )
                    }
                } catch {
                    print("[SpotifyInternalPlaybackBackend] Device poll failed (attempt \(attempt)): \(error.localizedDescription)")
                    PlayerInitLogger.shared.log(
                        "Device poll failed (attempt \(attempt)): \(error.localizedDescription)",
                        source: "SpotifyInternalPlaybackBackend"
                    )
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s between attempts
            }

            print("[SpotifyInternalPlaybackBackend] Device poll: internal player not found after \(maxAttempts) attempts")
            PlayerInitLogger.shared.log(
                "Device poll: internal player not found after \(maxAttempts) attempts",
                source: "SpotifyInternalPlaybackBackend"
            )
            onError?(.backend(message: "Internal player device not detected. Make sure the Electron process is running."))
        }
    }
}
