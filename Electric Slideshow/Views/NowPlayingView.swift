//
//  NowPlayingView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/26/25.
//

import SwiftUI

/// Main Now Playing screen that will host slideshow + music playback
struct NowPlayingView: View {
    @EnvironmentObject private var nowPlayingStore: NowPlayingStore
    @EnvironmentObject private var photoService: PhotoLibraryService
    @EnvironmentObject private var spotifyAuthService: SpotifyAuthService
    @EnvironmentObject private var playlistsStore: PlaylistsStore

    @StateObject private var spotifyAPIService = SpotifyAPIService(authService: SpotifyAuthService.shared)
    @StateObject private var playbackBridge = NowPlayingPlaybackBridge()

    private let bottomBarHeight: CGFloat = 56

    var body: some View {
        ZStack {
            // Match the app’s general background style
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                mainContent

                NowPlayingBottomBar(slideshow: nowPlayingStore.activeSlideshow)
                    .frame(height: bottomBarHeight)
            }
        }
        .environmentObject(playbackBridge)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if let slideshow = nowPlayingStore.activeSlideshow {
            HStack(spacing: 0) {
                // LEFT: Slideshow playback fills the remaining space
                SlideshowPlaybackView(
                    slideshow: slideshow,
                    photoService: photoService,
                    spotifyAPIService: spotifyAuthService.isAuthenticated ? spotifyAPIService : nil,
                    playlistsStore: playlistsStore,
                    onViewModelReady: { viewModel in
                        // When the playback view comes to life, wire its controls to the bridge
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
                )
                .focusable(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // RIGHT: New sidebar (fixed width)
                NowPlayingSidebarView(slideshow: slideshow)
            }
        } else {
            // Empty state when nothing is playing
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea(edges: .horizontal)

                ContentUnavailableView {
                    Label("Nothing Playing", systemImage: "play.circle")
                } description: {
                    Text("No slideshow is currently playing. Go to Slideshows to create or start one.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Right-hand sidebar shown only in the Now Playing view.
/// Stage 4: visually polished media controls with dynamic play/pause icons.
private struct NowPlayingSidebarView: View {
    let slideshow: Slideshow

    @EnvironmentObject private var playbackBridge: NowPlayingPlaybackBridge

    // You can tweak this later for design, but 280–320 is a good media-app width.
    private let sidebarWidth: CGFloat = 300

    // MARK: - Derived state

    private var hasSlides: Bool {
        playbackBridge.totalSlides > 0
    }

    private var slideshowPlayPauseIconName: String {
        playbackBridge.isSlideshowPlaying ? "pause.fill" : "play.fill"
    }

    private var musicPlayPauseIconName: String {
        playbackBridge.isMusicPlaying ? "pause.fill" : "play.fill"
    }

    private var slidePositionText: String {
        let total = playbackBridge.totalSlides
        guard total > 0 else {
            return "No photos loaded"
        }

        let current = min(max(playbackBridge.currentSlideIndex + 1, 1), total)
        return "Photo \(current) of \(total)"
    }

    private var trackDisplayText: String {
        let title = playbackBridge.currentTrackTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = playbackBridge.currentTrackArtist.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else {
            return "No track playing"
        }

        if artist.isEmpty {
            return title
        } else {
            return "\(title) – \(artist)"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: - Slideshow section

            VStack(alignment: .leading, spacing: 10) {
                Text("Slideshow")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(slideshow.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(slidePositionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    // Previous slide
                    Button {
                        playbackBridge.goToPreviousSlide?()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasSlides)

                    // Play / Pause slideshow
                    Button {
                        playbackBridge.togglePlayPause?()
                    } label: {
                        Image(systemName: slideshowPlayPauseIconName)
                            .font(.title2)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(playbackBridge.isSlideshowPlaying ? .accentColor : .primary)
                    .disabled(!hasSlides)

                    // Next slide
                    Button {
                        playbackBridge.goToNextSlide?()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasSlides)
                }
            }

            Divider()

            // MARK: - Music section

            VStack(alignment: .leading, spacing: 10) {
                Text("Music")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(trackDisplayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Clip length picker
                Picker("Clip length", selection: Binding(
                    get: { playbackBridge.clipMode },
                    set: { newValue in
                        playbackBridge.clipMode = newValue
                        playbackBridge.onClipModeChanged?(newValue)
                    }
                )) {
                    ForEach(MusicClipMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                HStack(spacing: 12) {
                    // Previous track
                    Button {
                        playbackBridge.musicPreviousTrack?()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)

                    // Play / Pause
                    Button {
                        playbackBridge.musicTogglePlayPause?()
                    } label: {
                        Image(systemName: musicPlayPauseIconName)
                            .font(.title2)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(playbackBridge.isMusicPlaying ? .accentColor : .primary)

                    // Next track
                    Button {
                        playbackBridge.musicNextTrack?()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                }
            }
            Spacer()
        }
        .padding(20)
        .frame(width: sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            // Slightly elevated panel look
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(radius: 2, x: 0, y: -1)
        )
        .padding(.leading, 12) // small gap from the slideshow content
    }
}

struct NowPlayingBottomBar: View {
    let slideshow: Slideshow?

    var body: some View {
        ZStack {
            // Toolbar-like background with a top divider
            Color(nsColor: .windowBackgroundColor)
                .overlay(
                    Divider(),
                    alignment: .top
                )

            HStack {
                // Left side: basic status
                if let slideshow {
                    Text("Now Playing: \(slideshow.title)")
                        .font(.subheadline)
                } else {
                    Text("Nothing playing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Right side: hint that controls are in the sidebar
                Text("Playback controls are in the sidebar →")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(NowPlayingStore())
}
