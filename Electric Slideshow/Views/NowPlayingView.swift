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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// Bottom bar for slideshow + music controls.
/// For Phase 3 this is primarily visual; we'll wire real actions later.
private struct NowPlayingBottomBar: View {
    let slideshow: Slideshow?

    @EnvironmentObject private var playbackBridge: NowPlayingPlaybackBridge

    var body: some View {
        ZStack {
            // Simple toolbar-like background with a top divider
            Color(nsColor: .windowBackgroundColor)
                .overlay(
                    Divider(),
                    alignment: .top
                )

            HStack(spacing: 16) {
                // Left: Slideshow controls
                HStack(spacing: 12) {
                    Button {
                        playbackBridge.goToPreviousSlide?()
                    } label: {
                        Image(systemName: "backward.end.fill")
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)

                    Button {
                        playbackBridge.togglePlayPause?()
                    } label: {
                        Image(systemName: "playpause.fill")
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)

                    Button {
                        playbackBridge.goToNextSlide?()
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)

                    Divider()
                        .frame(height: 24)

                    if let slideshow {
                        Text(slideshow.title)
                            .font(.subheadline)
                            .lineLimit(1)
                    } else {
                        Text("No slideshow")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Right: Music / track controls
                HStack(spacing: 12) {
                    // Previous track
                    Button {
                        playbackBridge.musicPreviousTrack?()
                    } label: {
                        Image(systemName: "backward.fill")
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)

                    // Play/Pause music only (does NOT affect slideshow)
                    Button {
                        playbackBridge.musicTogglePlayPause?()
                    } label: {
                        Image(systemName: "playpause.fill")
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)

                    // Next track
                    Button {
                        playbackBridge.musicNextTrack?()
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)

                    Divider()
                        .frame(height: 24)

                    // Placeholder text – we can wire real track info later
                    Text("Spotify")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(NowPlayingStore())
}
