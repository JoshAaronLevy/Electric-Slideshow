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
    
    private var slideTimer: Timer?
    private var playbackCheckTimer: Timer?
    private var musicClipTimer: Timer?
    private let slideshow: Slideshow
    private let photoService: PhotoLibraryService
    private let spotifyAPIService: SpotifyAPIService?
    private let playlistsStore: PlaylistsStore?
    private var playbackIndices: [Int] = []
    private var musicClipMode: MusicClipMode = .seconds30
    
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
        playlistsStore: PlaylistsStore? = nil
    ) {
        self.slideshow = slideshow
        self.photoService = photoService
        self.spotifyAPIService = spotifyAPIService
        self.playlistsStore = playlistsStore
    }
    
    // MARK: - Lifecycle
    
    func startPlayback() async {
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

    /// Starts the clip timer for the given duration (in seconds).
    private func startMusicClipTimer(duration: TimeInterval) {
        stopMusicClipTimer()

        musicClipTimer = Timer.scheduledTimer(
            withTimeInterval: duration,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // After the clip window ends, move to the next track
                await self.skipToNextTrack()
                // And arm the timer again for the next track
                self.resetMusicClipTimerForCurrentTrack()
            }
        }
    }

    /// Cancels any existing music clip timer.
    private func stopMusicClipTimer() {
        musicClipTimer?.invalidate()
        musicClipTimer = nil
    }

    /// Starts or restarts the timer that will advance to the next track
    /// after the configured clip duration. If the mode is `.fullSong`, no timer is scheduled.
    /// For `.seconds60`, the clip starts at a random point in the song.
    private func resetMusicClipTimerForCurrentTrack() {
        stopMusicClipTimer()

        // Only schedule if we have a finite clip duration
        guard let clipDuration = musicClipMode.clipDuration else {
            return // Full song → no timer, no seek
        }

        // Capture current mode and duration at this moment (in case user changes it later)
        let modeAtScheduling = musicClipMode

        // If we don't have a Spotify service, just behave like "start from 0, run for duration"
        guard let apiService = spotifyAPIService else {
            startMusicClipTimer(duration: clipDuration)
            return
        }

        Task { [weak self] in
            guard let self else { return }

            // Default behavior: start at 0 unless we can randomize
            var startMs = 0

            // We only randomize for the 60-second clip mode (per your spec).
            if modeAtScheduling == .seconds60 || modeAtScheduling == .seconds30 {
                do {
                    // Get current playback state (includes the active track and its duration)
                    if let state = try await apiService.getCurrentPlaybackState(),
                       let track = state.item {

                        let durationMs = track.durationMs
                        let clipMs = Int(clipDuration * 1000)

                        if durationMs > clipMs {
                            let maxStart = durationMs - clipMs
                            startMs = Int.random(in: 0...maxStart)
                        } else {
                            // Track is shorter than the clip → just start at 0
                            startMs = 0
                        }
                    }
                } catch {
                    print("[SlideshowPlaybackViewModel] Failed to fetch playback state for random clip: \(error)")
                }

                do {
                    // If we computed a non-zero start, seek into the track
                    if startMs > 0 {
                        try await apiService.seekToPosition(positionMs: startMs)
                    }
                } catch {
                    print("[SlideshowPlaybackViewModel] Failed to seek for random clip: \(error)")
                }
            }

            // Finally, arm the timer for this clip duration on the main actor
            await MainActor.run {
                self.startMusicClipTimer(duration: clipDuration)
            }
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

        // Ensure the Spotify macOS app exists and is launched (if available)
        let desktopReady = await ensureSpotifyDesktopAvailable()
        if !desktopReady {
            // In the “missing app” or “failed to launch” cases, we’ve already set error UI.
            return
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

            // Prefer an active device, then a “Computer” (this Mac), then just the first one
            let targetDevice =
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
        guard
            slideshow.settings.linkedPlaylistId != nil,
            let apiService = spotifyAPIService
        else {
            return
        }

        // Stop any active clip timer when pausing music
        stopMusicClipTimer()

        Task {
            do {
                try await apiService.pausePlayback()
            } catch {
                // Don’t break the slideshow if Spotify pause fails
                print("[SlideshowPlaybackViewModel] Failed to pause Spotify playback: \(error)")
            }
        }
    }

    // Called when the slideshow is resumed by the user (or music-only toggle is used)
    private func resumeMusicIfNeeded() {
        guard
            slideshow.settings.linkedPlaylistId != nil,
            let apiService = spotifyAPIService
        else {
            return
        }

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
    
    private func checkPlaybackState() async {
        guard let apiService = spotifyAPIService else { return }
        
        do {
            currentPlaybackState = try await apiService.getCurrentPlaybackState()
        } catch {
            // Silently fail
        }
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
    
    func skipToNextTrack() async {
        guard let apiService = spotifyAPIService else { return }
        
        do {
            try await apiService.skipToNext()
            await checkPlaybackState()
            // New track → restart the clip timer (if active)
            resetMusicClipTimerForCurrentTrack()
        } catch {
            errorMessage = "Failed to skip track"
        }
    }
    
    func skipToPreviousTrack() async {
        guard let apiService = spotifyAPIService else { return }
        
        do {
            try await apiService.skipToPrevious()
            await checkPlaybackState()
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
