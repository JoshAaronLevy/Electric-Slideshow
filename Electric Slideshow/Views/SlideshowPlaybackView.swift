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

            // Also wire directly into the playbackBridge in case we ever want to
            // use it from other contexts (not strictly required for Stage 3,
            // but keeps things consistent).
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
        .alert("Music Playback Failed", isPresented: $viewModel.showingMusicError) {
            Button("Continue Without Music") {
                viewModel.showingMusicError = false
            }
            Button("Cancel", role: .cancel) {
                viewModel.showingMusicError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unable to start music playback. Make sure Spotify is open on this device.")
        }
        .background(Color.black.ignoresSafeArea())
    }
}
