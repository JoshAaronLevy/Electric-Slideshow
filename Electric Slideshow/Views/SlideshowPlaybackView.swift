import SwiftUI
import AppKit

struct SlideshowPlaybackView: View {
    @StateObject private var viewModel: SlideshowPlaybackViewModel
    @EnvironmentObject private var playbackBridge: NowPlayingPlaybackBridge
    @FocusState private var isFocused: Bool

    private let onViewModelReady: ((SlideshowPlaybackViewModel) -> Void)?

    init(
        slideshow: Slideshow,
        photoService: PhotoLibraryService,
        spotifyAPIService: SpotifyAPIService?,
        playlistsStore: PlaylistsStore?,
        onViewModelReady: ((SlideshowPlaybackViewModel) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: SlideshowPlaybackViewModel(
            slideshow: slideshow,
            photoService: photoService,
            spotifyAPIService: spotifyAPIService,
            playlistsStore: playlistsStore
        ))
        self.onViewModelReady = onViewModelReady
    }
    
    var body: some View {
        ZStack {
            // Full-screen black background
            Color.black
                .ignoresSafeArea(edges: .all)
            
            // Current slide image
            if viewModel.isLoading {
                ProgressView("Loading images...")
                    .foregroundStyle(.white)
            } else if let image = viewModel.currentImage {
                GeometryReader { geometry in
                    ZStack {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .id(viewModel.currentIndex) // Force view update
                            .transition(.opacity)

                        // Paused state overlay
                        if !viewModel.isPlaying {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 96))
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(radius: 10)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Only interaction with the photo: toggle slideshow + music play/pause
                        viewModel.togglePlayPause()
                    }
                }
                .ignoresSafeArea(edges: .all)
            }
        }
        .animation(.easeInOut(duration: 1.0), value: viewModel.currentIndex)
        .task {
            await viewModel.startPlayback()
        }
        .onAppear {
            // Let the parent know about our view model so it can bridge controls
            onViewModelReady?(viewModel)

            // Wire commands into the playbackBridge
            playbackBridge.goToPreviousSlide = {
                if viewModel.hasPreviousSlide {
                    viewModel.previousSlide()
                }
            }

            playbackBridge.togglePlayPause = {
                viewModel.togglePlayPause()
            }

            playbackBridge.goToNextSlide = {
                if viewModel.hasNextSlide {
                    viewModel.nextSlide()
                }
            }

            // Music-only controls
            playbackBridge.musicPreviousTrack = {
                Task {
                    await viewModel.skipToPreviousTrack()
                }
            }

            playbackBridge.musicTogglePlayPause = {
                viewModel.toggleMusicPlayPause()
            }

            playbackBridge.musicNextTrack = {
                Task {
                    await viewModel.skipToNextTrack()
                }
            }

            // Seed the sidebar / bridge with the current state
            syncPlaybackBridge()
        }
        // Whenever the slideshow or playback state changes, mirror it into the bridge
        .onReceive(viewModel.$currentIndex) { _ in
            syncPlaybackBridge()
        }
        .onReceive(viewModel.$loadedImages) { _ in
            syncPlaybackBridge()
        }
        .onReceive(viewModel.$isPlaying) { _ in
            syncPlaybackBridge()
        }
        .onReceive(viewModel.$currentPlaybackState) { _ in
            syncPlaybackBridge()
        }
        .onDisappear {
            // Stop playback as before
            Task {
                await viewModel.stopPlayback()
            }

            // Clear out the bridge commands when this view goes away
            playbackBridge.goToPreviousSlide = nil
            playbackBridge.togglePlayPause = nil
            playbackBridge.goToNextSlide = nil

            playbackBridge.musicPreviousTrack = nil
            playbackBridge.musicTogglePlayPause = nil
            playbackBridge.musicNextTrack = nil

            // Clear mirrored state so the sidebar doesn't show stale info
            playbackBridge.currentSlideIndex = 0
            playbackBridge.totalSlides = 0
            playbackBridge.isSlideshowPlaying = false
            playbackBridge.currentTrackTitle = ""
            playbackBridge.currentTrackArtist = ""
            playbackBridge.isMusicPlaying = false
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(.space) {
            viewModel.togglePlayPause()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            if viewModel.hasPreviousSlide {
                viewModel.previousSlide()
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if viewModel.hasNextSlide {
                viewModel.nextSlide()
            }
            return .handled
        }
        .alert("Music Playback", isPresented: $viewModel.showingMusicError) {
            if viewModel.requiresSpotifyAppInstall {
                // Missing Spotify app case
                Button("Download Spotify") {
                    viewModel.openSpotifyDownloadPage()
                    viewModel.showingMusicError = false
                }
                Button("Dismiss", role: .cancel) {
                    viewModel.showingMusicError = false
                }
            } else {
                // Generic playback error case
                Button("Continue Without Music") {
                    viewModel.showingMusicError = false
                }
                Button("Dismiss", role: .cancel) {
                    viewModel.showingMusicError = false
                }
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unable to start music playback. Make sure Spotify is open on this device.")
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    // MARK: - Bridge state syncing

    /// Mirror the current slideshow + music state into the NowPlayingPlaybackBridge
    /// so that other views (like the sidebar) can display it.
    private func syncPlaybackBridge() {
        // Slides
        playbackBridge.currentSlideIndex = viewModel.currentIndex
        playbackBridge.totalSlides = viewModel.loadedImages.count
        playbackBridge.isSlideshowPlaying = viewModel.isPlaying

        // Music / Spotify
        if let playback = viewModel.currentPlaybackState,
           let track = playback.item {
            playbackBridge.currentTrackTitle = track.name
            playbackBridge.currentTrackArtist = track.artists.first?.name ?? ""
            playbackBridge.isMusicPlaying = playback.isPlaying
        } else {
            playbackBridge.currentTrackTitle = ""
            playbackBridge.currentTrackArtist = ""
            playbackBridge.isMusicPlaying = false
        }
    }
}
