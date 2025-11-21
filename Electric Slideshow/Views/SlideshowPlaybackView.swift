import SwiftUI

/// Full-screen slideshow playback view with controls and music integration
struct SlideshowPlaybackView: View {
    @StateObject private var viewModel: SlideshowPlaybackViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var lastMouseMovement = Date()
    
    init(
        slideshow: Slideshow,
        photoService: PhotoLibraryService,
        spotifyAPIService: SpotifyAPIService?,
        playlistsStore: PlaylistsStore?
    ) {
        self._viewModel = StateObject(
            wrappedValue: SlideshowPlaybackViewModel(
                slideshow: slideshow,
                photoService: photoService,
                spotifyAPIService: spotifyAPIService,
                playlistsStore: playlistsStore
            )
        )
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Current slide image
            if viewModel.isLoading {
                ProgressView("Loading images...")
                    .foregroundStyle(.white)
            } else if let image = viewModel.currentImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .id(viewModel.currentIndex) // Force view update
                    .transition(.opacity)
            }
            
            // Controls overlay
            if showControls {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.0), value: viewModel.currentIndex)
        .task {
            await viewModel.startPlayback()
        }
        .onDisappear {
            Task {
                await viewModel.stopPlayback()
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                onMouseActivity()
            case .ended:
                break
            }
        }
        .onKeyPress(.space) {
            viewModel.togglePlayPause()
            onMouseActivity()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            if viewModel.hasPreviousSlide {
                viewModel.previousSlide()
                onMouseActivity()
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if viewModel.hasNextSlide {
                viewModel.nextSlide()
                onMouseActivity()
            }
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .alert("Music Playback Failed", isPresented: $viewModel.showingMusicError) {
            Button("Continue Without Music") {
                viewModel.showingMusicError = false
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unable to start music playback. Make sure Spotify is open on this device.")
        }
    }
    
    // MARK: - Controls Overlay
    
    private var controlsOverlay: some View {
        ZStack {
            // Top bar - Close button and progress
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    Text(viewModel.progressText)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                }
                .padding()
                
                Spacer()
            }
            
            // Bottom bar - Playback and music controls
            VStack {
                Spacer()
                
                HStack(spacing: 24) {
                    // Slide controls
                    Button {
                        viewModel.previousSlide()
                        onMouseActivity()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.hasPreviousSlide)
                    .opacity(viewModel.hasPreviousSlide ? 1.0 : 0.3)
                    
                    Button {
                        viewModel.togglePlayPause()
                        onMouseActivity()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        viewModel.nextSlide()
                        onMouseActivity()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.hasNextSlide)
                    .opacity(viewModel.hasNextSlide ? 1.0 : 0.3)
                    
                    // Music controls (if music is playing)
                    if let playbackState = viewModel.currentPlaybackState {
                        Rectangle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 1, height: 30)
                        
                        musicControls(playbackState: playbackState)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Music Controls
    
    @ViewBuilder
    private func musicControls(playbackState: SpotifyPlaybackState) -> some View {
        HStack(spacing: 16) {
            // Previous track
            Button {
                Task {
                    await viewModel.skipToPreviousTrack()
                    onMouseActivity()
                }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.body)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            
            // Play/pause music
            Button {
                Task {
                    await viewModel.toggleMusicPlayPause()
                    onMouseActivity()
                }
            } label: {
                Image(systemName: playbackState.isPlaying ? "pause.circle" : "play.circle")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            
            // Next track
            Button {
                Task {
                    await viewModel.skipToNextTrack()
                    onMouseActivity()
                }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.body)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            
            // Current song info
            if let track = playbackState.item {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(track.artistNames)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(maxWidth: 200, alignment: .leading)
            }
        }
    }
    
    // MARK: - Mouse Activity Tracking
    
    private func onMouseActivity() {
        lastMouseMovement = Date()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls = true
        }
        
        // Reset auto-hide timer
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            if Date().timeIntervalSince(lastMouseMovement) >= 3.0 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls = false
                }
            }
        }
    }
}
