import Foundation
import AppKit
import Combine
internal import Photos

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
    
    private var slideTimer: Timer?
    private var playbackCheckTimer: Timer?
    private let slideshow: Slideshow
    private let photoService: PhotoLibraryService
    private let spotifyAPIService: SpotifyAPIService?
    private let playlistsStore: PlaylistsStore?
    private var playbackIndices: [Int] = []
    
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
        await stopMusic()
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
            startSlideTimer()
        } else {
            stopSlideTimer()
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
        guard let playlistId = slideshow.settings.linkedPlaylistId,
              let playlistsStore = playlistsStore,
              let apiService = spotifyAPIService else {
            // No music configured or Spotify not available
            return
        }
        
        // Find the app playlist
        guard let playlist = playlistsStore.playlists.first(where: { $0.id == playlistId }) else {
            errorMessage = "Playlist not found"
            return
        }
        
        guard !playlist.trackURIs.isEmpty else {
            errorMessage = "Playlist is empty"
            return
        }
        
        do {
            try await apiService.startPlayback(trackURIs: playlist.trackURIs)
        } catch {
            showingMusicError = true
            errorMessage = "Failed to start music playback. Make sure Spotify is open on this device."
        }
    }
    
    private func stopMusic() async {
        guard spotifyAPIService != nil else { return }
        
        do {
            try await spotifyAPIService?.pausePlayback()
        } catch {
            // Ignore stop errors
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
    
    func skipToNextTrack() async {
        guard let apiService = spotifyAPIService else { return }
        
        do {
            try await apiService.skipToNext()
            await checkPlaybackState()
        } catch {
            errorMessage = "Failed to skip track"
        }
    }
    
    func skipToPreviousTrack() async {
        guard let apiService = spotifyAPIService else { return }
        
        do {
            try await apiService.skipToPrevious()
            await checkPlaybackState()
        } catch {
            errorMessage = "Failed to skip track"
        }
    }
}
