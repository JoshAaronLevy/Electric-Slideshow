import Foundation
import Combine
import Photos
import AppKit

/// ViewModel for managing slideshow playback with music integration
@MainActor
final class SlideshowPlaybackViewModel: ObservableObject {
    @Published var currentIndex: Int = 0
    @Published var isPlaying: Bool = true
    @Published var loadedImages: [NSImage] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    @Published var showingMusicError: Bool = false
    @Published var currentPlaybackState: SpotifyPlaybackState?
    /// When true, the music error alert should offer a “Download Spotify” button
    /// rather than just “Continue without music”.
    @Published var requiresSpotifyAppInstall: Bool = false
    @Published var normalizedPlaybackState: PlaybackState = .idle
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: PlaybackRepeatMode = .off
    
    private var slideTimer: Timer?
    private var playbackCheckTimer: Timer?
    private var musicClipTimer: Timer?
    private let slideshow: Slideshow
    private let photoService: PhotoLibraryService
    private let spotifyAPIService: SpotifyAPIService?
    private let playlistsStore: PlaylistsStore?
    private var playbackIndices: [Int] = []
    private var musicClipMode: MusicClipMode = .seconds60
    private var lastClipAppliedTrackUri: String?
    private let minCustomClipWindowMs = 3000
    private let minSafeClipSeconds: Double = 1.0
    private let playbackStartToleranceMs = 750
    private let musicBackend: MusicPlaybackBackend?

    private var backendDescription: String {
        guard let backend = musicBackend else { return "none" }
        return backend.requiresExternalApp ? "external" : "internal"
    }

    private var currentTrackUri: String? {
        normalizedPlaybackState.trackUri ?? currentPlaybackState?.item?.uri
    }
    
    var currentImage: NSImage? {
        guard currentIndex < loadedImages.count else { return nil }
        return loadedImages[currentIndex]
    }
    
    var progressText: String {
        "\(currentIndex + 1) of \(slideshow.photoCount)"
    }
    
    var hasNextSlide: Bool {
        if slideshow.settings.repeatEnabled {
            return true
        }
        return currentIndex < loadedImages.count - 1
    }
    
    var hasPreviousSlide: Bool {
        if slideshow.settings.repeatEnabled {
            return true
        }
        return currentIndex > 0
    }
    
    init(
        slideshow: Slideshow,
        photoService: PhotoLibraryService,
        spotifyAPIService: SpotifyAPIService? = nil,
        playlistsStore: PlaylistsStore? = nil,
        musicBackend: MusicPlaybackBackend? = nil
    ) {
        self.slideshow = slideshow
        self.photoService = photoService
        self.spotifyAPIService = spotifyAPIService
        self.playlistsStore = playlistsStore
        self.musicBackend = musicBackend

        setupMusicBackendCallbacks()
    }
    
    // MARK: - Lifecycle
    
    func startPlayback() async {
        musicBackend?.initialize()
        await loadAllImages()
        setupPlaybackOrder()
        await startMusic()
        startSlideTimer()
        startPlaybackStateMonitoring()
    }
    
    func stopPlayback() async {
        stopSlideTimer()
        stopPlaybackStateMonitoring()
        stopMusicClipTimer()
        await stopMusic()
    }

    // MARK: - Music clip mode

    /// Updates the current clip mode used for music playback.
    /// Stage 2: stores the value and updates any active clip timer.
    func updateClipMode(_ mode: MusicClipMode) {
        musicClipMode = mode

        // If we're in full-song mode, cancel any existing timer.
        guard musicClipMode.clipDuration != nil else {
            stopMusicClipTimer()
            return
        }

        // Only (re)start the timer if music is currently playing.
        if currentPlaybackState?.isPlaying == true {
            resetMusicClipTimerForCurrentTrack()
        } else {
            // No active playback → no timer.
            stopMusicClipTimer()
        }
    }

    /// Connects the music backend's callbacks to this view model so that
    /// backend-agnostic PlaybackState can drive the UI.
    private func setupMusicBackendCallbacks() {
        guard let backend = musicBackend else { return }

        backend.onStateChanged = { [weak self] state in
            // Ensure UI updates happen on main actor
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.normalizedPlaybackState = state
            }
        }

        backend.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // You can keep this as simple logging, or surface it via your
                // existing error UI. Here's a minimal version:
                print("[SlideshowPlaybackViewModel] Playback backend error: \(error)")

                // Optional: hook into your music error UI if you want
                // self.errorMessage = "Music playback error"
                // self.showingMusicError = true
            }
        }
    }

    /// Starts the clip timer for the given duration (in seconds).
    private func startMusicClipTimer(duration: TimeInterval, reason: String = "clipWindow") {
        stopMusicClipTimer()
        let trackLabel = currentTrackUri ?? "unknown"
        print("[SlideshowPlaybackViewModel] Starting clip timer for track=\(trackLabel) backend=\(backendDescription) duration=\(String(format: "%.2f", duration))s reason=\(reason)")

        musicClipTimer = Timer.scheduledTimer(
            withTimeInterval: duration,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let firedTrackLabel = self.currentTrackUri ?? "unknown"
                print("[SlideshowPlaybackViewModel] Clip timer fired for track=\(firedTrackLabel) backend=\(self.backendDescription)")
                // After the clip window ends, move to the next track
                await self.skipToNextTrack(fromClipTimer: true)
            }
        }
    }

    /// Cancels any existing music clip timer.
    private func stopMusicClipTimer() {
        musicClipTimer?.invalidate()
        musicClipTimer = nil
    }

    /// Applies the current clip settings (custom, playlist default, or global) to the active track.
    /// Seeks to the correct start and arms a timer to advance when the clip window ends.
    private func resetMusicClipTimerForCurrentTrack() {
        Task { @MainActor [weak self] in
            await self?.applyClipForCurrentTrack()
        }
    }

    // MARK: - Image Loading
    
    private func loadAllImages() async {
        isLoading = true
        let size = CGSize(width: 1920, height: 1080) // Full HD
        
        var images: [NSImage] = []
        for photo in slideshow.photos {
            // Fetch the PHAsset using the local identifier
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photo.localIdentifier], options: nil)
            guard let phAsset = fetchResult.firstObject else {
                print("Warning: Could not find photo with identifier \(photo.localIdentifier)")
                continue
            }
            
            let photoAsset = PhotoAsset(asset: phAsset)
            if let image = await photoService.image(for: photoAsset, size: size) {
                images.append(image)
            } else {
                // Photo might have been deleted from library
                print("Warning: Could not load photo \(photo.localIdentifier)")
            }
        }
        
        if images.isEmpty {
            errorMessage = "No photos could be loaded"
            isLoading = false
            return
        }
        
        loadedImages = images
        isLoading = false
    }
    
    private func setupPlaybackOrder() {
        if slideshow.settings.shuffle {
            playbackIndices = Array(0..<loadedImages.count).shuffled()
        } else {
            playbackIndices = Array(0..<loadedImages.count)
        }
    }
    
    // MARK: - Slide Navigation
    
    func nextSlide() {
        guard hasNextSlide else { return }
        
        if currentIndex >= loadedImages.count - 1 {
            // Loop back to start
            currentIndex = 0
        } else {
            currentIndex += 1
        }
    }
    
    func previousSlide() {
        guard hasPreviousSlide else { return }
        
        if currentIndex <= 0 {
            // Loop to end
            currentIndex = loadedImages.count - 1
        } else {
            currentIndex -= 1
        }
    }
    
    func togglePlayPause() {
        isPlaying.toggle()
        
        if isPlaying {
            // Resume slideshow timer
            startSlideTimer()
            // Resume Spotify from where it left off
            resumeMusicIfNeeded()
        } else {
            // Pause slideshow timer
            stopSlideTimer()
            // Pause Spotify playback
            pauseMusicIfNeeded()
        }
    }
    
    // MARK: - Slide Timer
    
    private func startSlideTimer() {
        stopSlideTimer()
        
        slideTimer = Timer.scheduledTimer(
            withTimeInterval: slideshow.settings.durationPerSlide,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.nextSlide()
                
                // Check if we should stop (no repeat and at end)
                if let self = self,
                   !self.slideshow.settings.repeatEnabled,
                   self.currentIndex >= self.loadedImages.count - 1 {
                    self.stopSlideTimer()
                    self.isPlaying = false
                }
            }
        }
    }
    
    private func stopSlideTimer() {
        slideTimer?.invalidate()
        slideTimer = nil
    }
    
    // MARK: - Music Playback
    
    private func startMusic() async {
        guard let apiService = spotifyAPIService else { return }
        guard let playlistId = slideshow.settings.linkedPlaylistId,
            let playlist = playlistsStore?.playlists.first(where: { $0.id == playlistId })
        else {
            return
        }

        // 1. Ensure the playback environment is ready
        if let backend = musicBackend, !backend.requiresExternalApp {
            // Internal player: wait for it to be ready
            print("[SlideshowPlaybackViewModel] Waiting for internal player to be ready...")
            
            // Simple polling loop to wait for backend.isReady
            let timeout = Date().addingTimeInterval(10) // 10s timeout
            while !backend.isReady && Date() < timeout {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
            
            if !backend.isReady {
                print("[SlideshowPlaybackViewModel] Internal player failed to become ready in time.")
                showingMusicError = true
                errorMessage = "Internal music player failed to initialize."
                return
            }
        } else {
            // External player: Ensure the Spotify macOS app exists and is launched
            let desktopReady = await ensureSpotifyDesktopAvailable()
            if !desktopReady {
                return
            }
        }

        do {
            let devices = try await apiService.fetchAvailableDevices()

            guard !devices.isEmpty else {
                showingMusicError = true
                errorMessage =
                    "We couldn’t find any Spotify playback devices on your account.\n\n" +
                    "Open Spotify on this Mac or another device and try again."
                return
            }

            // Prefer the internal player if available, then active, then computer
            let targetDevice =
                devices.first(where: { $0.name == "Electric Slideshow Internal Player" }) ??
                devices.first(where: { $0.is_active }) ??
                devices.first(where: { $0.type.lowercased() == "computer" }) ??
                devices.first!

            print("[SlideshowPlaybackViewModel] Using Spotify device: \(targetDevice.name) (\(targetDevice.type))")

            try await apiService.startPlayback(
                trackURIs: playlist.trackURIs,
                deviceId: targetDevice.deviceId
            )
            resetMusicClipTimerForCurrentTrack()
        } catch let playbackError as SpotifyAPIService.PlaybackError {
            switch playbackError {
            case .noActiveDevice(let message):
                showingMusicError = true
                errorMessage = (
                    message.isEmpty
                    ? "Spotify couldn’t find an active playback device.\n\n" +
                    "Make sure Spotify is open on this Mac or another device " +
                    "and start playing any track once, then try again."
                    : message
                )

            case .generic(let message):
                showingMusicError = true
                errorMessage = message.isEmpty ?
                    "Couldn’t start Spotify playback." :
                    message
            }
        } catch {
            showingMusicError = true
            errorMessage = "Couldn’t start Spotify playback."
        }
    }

    // MARK: - Spotify Desktop Integration

    /// Ensures that the Spotify macOS app is installed, and launches it if needed.
    /// - Returns: `true` if the app is installed (launched or already running), `false` if not installed.
    @MainActor
    private func ensureSpotifyDesktopAvailable() async -> Bool {
        let bundleId = "com.spotify.client"
        let workspace = NSWorkspace.shared

        // Reset any previous “missing app” state
        requiresSpotifyAppInstall = false

        // 1. Check if the Spotify app is installed at all
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) else {
            // Not installed → show a specific error and mark that we need to offer “Download”
            errorMessage =
                """
                Spotify for macOS does not appear to be installed.

                To enable music playback in Electric Slideshow, you’ll need:
                • The Spotify app installed on this Mac
                • An active Spotify Premium subscription
                """
            requiresSpotifyAppInstall = true
            showingMusicError = true
            return false
        }

        // 2. If it is installed but not running, launch it
        let isRunning = workspace.runningApplications.contains { $0.bundleIdentifier == bundleId }

        if !isRunning {
            do {
                // Launch Spotify **without** activating it (don’t steal focus)
                try workspace.launchApplication(
                    at: appURL,
                    options: [.withoutActivation],
                    configuration: [:]
                )

                // Give Spotify a brief moment to launch and register as a device
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

                // Make sure Electric Slideshow stays / comes back to the front
                NSApplication.shared.activate(ignoringOtherApps: true)
            } catch {
                print("[SlideshowPlaybackViewModel] Failed to launch Spotify app: \(error)")
                errorMessage = "Couldn’t open the Spotify app on this Mac."
                showingMusicError = true
                return false
            }
        }

        return true
    }
    
    private func stopMusic() async {
        guard spotifyAPIService != nil else { return }
        
        stopMusicClipTimer()

        do {
            try await spotifyAPIService?.pausePlayback()
        } catch {
            // Ignore stop errors
        }
    }

    private func pauseMusicIfNeeded() {
        guard slideshow.settings.linkedPlaylistId != nil else {
            return
        }

        // Stop any active clip timer when pausing music
        stopMusicClipTimer()

        if let backend = musicBackend {
            backend.pause()
            return
        }

        // Fallback: direct API call if no backend is present
        guard let apiService = spotifyAPIService else { return }

        Task {
            do {
                try await apiService.pausePlayback()
            } catch {
                // Don’t break the slideshow if Spotify pause fails
                print("[SlideshowPlaybackViewModel] Failed to pause Spotify playback: \(error)")
            }
        }
    }

    private func resumeMusicIfNeeded() {
        guard slideshow.settings.linkedPlaylistId != nil else {
            return
        }

        if let backend = musicBackend {
            // Backend handles the async call; we just re-arm the clip timer
            backend.resume()
            // Re-arm the clip timer if a clip mode is active
            resetMusicClipTimerForCurrentTrack()
            return
        }

        // Fallback: direct API call if no backend is present
        guard let apiService = spotifyAPIService else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                // Resume playback from wherever Spotify left off
                try await apiService.resumePlayback()
                // Re-arm the clip timer if a clip mode is active
                self.resetMusicClipTimerForCurrentTrack()
            } catch {
                print("[SlideshowPlaybackViewModel] Failed to resume Spotify playback: \(error)")
            }
        }
    }

    func setShuffleEnabled(_ isOn: Bool) {
        isShuffleEnabled = isOn
        musicBackend?.setShuffleEnabled(isOn)
    }

    func setRepeatAllEnabled(_ isOn: Bool) {
        repeatMode = isOn ? .all : .off
        musicBackend?.setRepeatMode(repeatMode)
    }

    /// Optional: convenience toggles for UI
    func toggleShuffle() {
        setShuffleEnabled(!isShuffleEnabled)
    }

    func toggleRepeatAll() {
        let newIsOn = (repeatMode != .all)
        setRepeatAllEnabled(newIsOn)
    }
    
    // MARK: - Playback State Monitoring
    
    private func startPlaybackStateMonitoring() {
        playbackCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkPlaybackState()
            }
        }
    }
    
    private func stopPlaybackStateMonitoring() {
        playbackCheckTimer?.invalidate()
        playbackCheckTimer = nil
    }
    
    private func checkPlaybackState(shouldRearmOnTrackChange: Bool = true) async {
        guard let apiService = spotifyAPIService else { return }
        
        do {
            let state = try await apiService.getCurrentPlaybackState()
            currentPlaybackState = state
            updateNormalizedPlaybackState(from: state)
            if shouldRearmOnTrackChange,
               let uri = state?.item?.uri,
               uri != lastClipAppliedTrackUri {
                resetMusicClipTimerForCurrentTrack()
            }
        } catch {
            // Silently fail
        }
    }

    /// Maps the Spotify-specific playback state into our normalized PlaybackState
    /// so the rest of the app doesn't need to know about Spotify's model.
    private func updateNormalizedPlaybackState(from playback: SpotifyPlaybackState?) {
        guard let playback, let track = playback.item else {
            normalizedPlaybackState = .idle
            return
        }

        normalizedPlaybackState = PlaybackState(
            trackUri: track.uri,
            trackName: track.name,
            artistName: track.artists.first?.name,
            positionMs: playback.progressMs ?? 0,
            durationMs: track.durationMs,
            isPlaying: playback.isPlaying,
            isBuffering: false
        )
    }

    // MARK: - Clip application (custom / playlist default / global)

    /// Applies the effective clip window for the current Spotify track (custom > playlist default > global).
    private func applyClipForCurrentTrack() async {
        stopMusicClipTimer()

        guard
            let apiService = spotifyAPIService,
            let playlistId = slideshow.settings.linkedPlaylistId,
            let playlist = playlistsStore?.playlists.first(where: { $0.id == playlistId })
        else {
            return
        }

        do {
            guard let playback = try await apiService.getCurrentPlaybackState(),
                  let item = playback.item else {
                return
            }

            let uri = item.uri
            let trackDuration = item.durationMs
            let progressMs = playback.progressMs ?? 0
            let playlistTrack = playlist.playlistTracks.first { $0.uri == uri }
            let clipWindow = effectiveClipWindow(
                track: playlistTrack,
                playlist: playlist,
                trackDurationMs: trackDuration
            )
            let startMs = clipWindow.startMs ?? 0
            let clipDurationMs = clipWindow.durationMs ?? trackDuration
            let clipWindowSeconds = Double(clipDurationMs) / 1000.0
            let hasReachedStart = progressMs >= max(startMs - playbackStartToleranceMs, 0)
            let playbackReady = playback.isPlaying || (hasReachedStart && progressMs > 0)

            guard trackDuration > 0 else {
                print("[SlideshowPlaybackViewModel] Clip not armed: invalid track duration (\(trackDuration)) for track=\(uri) backend=\(backendDescription)")
                return
            }

            guard playbackReady else {
                print("[SlideshowPlaybackViewModel] Deferring clip arming: playback not ready track=\(uri) backend=\(backendDescription) isPlaying=\(playback.isPlaying) progressMs=\(progressMs) startMs=\(startMs) hasReachedStart=\(hasReachedStart)")
                return
            }

            guard clipWindowSeconds >= minSafeClipSeconds else {
                print("[SlideshowPlaybackViewModel] Clip not armed: tiny/invalid window (\(String(format: "%.2f", clipWindowSeconds))s) track=\(uri) backend=\(backendDescription) trackDurationMs=\(trackDuration) clipDurationMs=\(clipDurationMs) startMs=\(startMs) -> playing without enforced clip")
                lastClipAppliedTrackUri = uri
                return
            }

            // Seek to the clip start if needed
            if startMs > 0 {
                if let backend = musicBackend, backend.isReady {
                    backend.seek(to: startMs)
                } else {
                    try await apiService.seekToPosition(positionMs: startMs)
                }
            }

            // Arm timer for clip duration
            startMusicClipTimer(duration: clipWindowSeconds, reason: "clipWindow")

            lastClipAppliedTrackUri = uri
        } catch {
            // If we fail to fetch state or seek, just leave playback running.
            print("[SlideshowPlaybackViewModel] Failed to apply clip: \(error)")
        }
    }

    private func effectiveClipWindow(
        track: PlaylistTrack?,
        playlist: AppPlaylist,
        trackDurationMs: Int?
    ) -> (startMs: Int?, durationMs: Int?) {
        let durationMsPreferred = trackDurationMs ?? track?.durationMs

        // Custom clip
        if let track, track.clipMode == .custom,
           let customWindow = customClipWindow(for: track, trackDurationMs: durationMsPreferred) {
            return customWindow
        }

        return defaultClipWindow(playlist: playlist, trackDurationMs: durationMsPreferred)
    }

    private func customClipWindow(
        for track: PlaylistTrack,
        trackDurationMs: Int?
    ) -> (startMs: Int, durationMs: Int)? {
        let start = max(0, track.customStartMs ?? 0)
        let rawEnd = track.customEndMs ?? (trackDurationMs ?? start)
        let boundedEnd = trackDurationMs.map { min(rawEnd, $0) } ?? rawEnd
        let duration = boundedEnd - start

        guard duration >= minCustomClipWindowMs else {
            return nil
        }

        if let durationMsPreferred = trackDurationMs {
            let maxDuration = max(durationMsPreferred - start, 0)
            guard maxDuration >= minCustomClipWindowMs else {
                return nil
            }
            return (start, min(duration, maxDuration))
        }

        return (start, duration)
    }

    private func defaultClipWindow(
        playlist: AppPlaylist,
        trackDurationMs: Int?
    ) -> (startMs: Int?, durationMs: Int?) {
        let mode = playlist.playlistDefaultClipMode ?? musicClipMode
        guard let clipSeconds = mode.clipDuration else {
            // Full song: no timer, play to natural end
            return (0, trackDurationMs)
        }

        let clipMs = Int(clipSeconds * 1000)
        let durationMs: Int
        let startMs: Int

        if let duration = trackDurationMs, duration > clipMs {
            // Random start within track if it can fit the clip window
            let maxStart = max(duration - clipMs, 0)
            startMs = maxStart > 0 ? Int.random(in: 0...maxStart) : 0
            durationMs = clipMs
        } else {
            startMs = 0
            durationMs = trackDurationMs.map { min($0, clipMs) } ?? clipMs
        }

        return (startMs, durationMs)
    }
    
    // MARK: - Music Controls
    
    func toggleMusicPlayPause() async {
        guard let apiService = spotifyAPIService,
              let state = currentPlaybackState else {
            return
        }
        
        do {
            if state.isPlaying {
                try await apiService.pausePlayback()
            } else {
                // Resume playback - empty array means resume current context
                try await apiService.startPlayback(trackURIs: [])
            }
            await checkPlaybackState()
        } catch {
            errorMessage = "Music control failed"
        }
    }

    /// Toggles **only** the Spotify playback (no effect on slideshow timer or slide index).
    func toggleMusicPlayPause() {
        // If we don't know the state yet, try to resume – it's more useful than a no-op.
        if let playback = currentPlaybackState {
            if playback.isPlaying {
                pauseMusicIfNeeded()
            } else {
                resumeMusicIfNeeded()
            }
        } else {
            // No state yet – optimistically try to resume
            resumeMusicIfNeeded()
        }
    }
    
    func skipToNextTrack(fromClipTimer: Bool = false) async {
        let trackLabel = currentTrackUri ?? "unknown"
        print("[SlideshowPlaybackViewModel] skipToNextTrack fromClipTimer=\(fromClipTimer) backend=\(backendDescription) track=\(trackLabel)")
        if let backend = musicBackend {
            backend.nextTrack()
            // New track → restart the clip timer (if active)
            resetMusicClipTimerForCurrentTrack()
            return
        }

        guard let apiService = spotifyAPIService else { return }

        do {
            try await apiService.skipToNext()
            await checkPlaybackState(shouldRearmOnTrackChange: false)
            // New track → restart the clip timer (if active)
            resetMusicClipTimerForCurrentTrack()
        } catch {
            errorMessage = "Failed to skip track"
        }
    }
    
    func skipToPreviousTrack() async {
        if let backend = musicBackend {
            backend.previousTrack()
            // New track → restart the clip timer (if active)
            resetMusicClipTimerForCurrentTrack()
            return
        }

        guard let apiService = spotifyAPIService else { return }

        do {
            try await apiService.skipToPrevious()
            await checkPlaybackState(shouldRearmOnTrackChange: false)
            // New track → restart the clip timer (if active)
            resetMusicClipTimerForCurrentTrack()
        } catch {
            errorMessage = "Failed to skip track"
        }
    }

    /// Opens the Spotify download page in the user’s default browser.
    @MainActor
    func openSpotifyDownloadPage() {
        guard let url = URL(string: "https://www.spotify.com/download/mac") else { return }
        NSWorkspace.shared.open(url)
    }
}
