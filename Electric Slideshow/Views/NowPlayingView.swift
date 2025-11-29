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
        VStack(alignment: .leading, spacing: 24) {
            // MARK: - SLIDESHOW

            SidebarSectionHeader(title: "Slideshow")

            // Info group: title + "Photo X of Y"
            VStack(alignment: .leading, spacing: 4) {
                Text(slideshow.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)

                Text(slidePositionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Controls group: primary transport row
            SlideshowTransportControlsRow(
                isPlaying: playbackBridge.isSlideshowPlaying,
                isEnabled: hasSlides,
                onPrevious: { playbackBridge.goToPreviousSlide?() },
                onPlayPause: { playbackBridge.togglePlayPause?() },
                onNext: { playbackBridge.goToNextSlide?() }
            )

            Divider()
                .padding(.vertical, 4)

            // MARK: - MUSIC

            SidebarSectionHeader(title: "Music")

            // Info group: track title + artist (slightly different weights)
            VStack(alignment: .leading, spacing: 4) {
                let title = playbackBridge.currentTrackTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let artist = playbackBridge.currentTrackArtist.trimmingCharacters(in: .whitespacesAndNewlines)

                if title.isEmpty {
                    Text("No track playing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if !artist.isEmpty {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            // Clip length control (kept close to the track info)
            VStack(alignment: .leading, spacing: 4) {
                Text("Clip length")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
                .frame(maxWidth: 180, alignment: .leading)
            }

            // Controls group: secondary transport row
            MusicTransportControlsRow(
                isPlaying: playbackBridge.isMusicPlaying,
                onPrevious: { playbackBridge.musicPreviousTrack?() },
                onPlayPause: { playbackBridge.musicTogglePlayPause?() },
                onNext: { playbackBridge.musicNextTrack?() }
            )

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

// Small, reusable "SLIDESHOW" / "MUSIC" style label
private struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(1) // slight letter spacing
    }
}

// Primary "media transport" row – used for the slideshow
private struct SlideshowTransportControlsRow: View {
    let isPlaying: Bool
    let isEnabled: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPrevious) {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!isEnabled)

            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(minWidth: 32, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isPlaying ? .accentColor : .primary)
            .disabled(!isEnabled)

            Button(action: onNext) {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!isEnabled)
        }
    }
}

// Secondary transport row – visually lighter, used for music
private struct MusicTransportControlsRow: View {
    let isPlaying: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(minWidth: 28, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(isPlaying ? .accentColor : .primary)

            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
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
