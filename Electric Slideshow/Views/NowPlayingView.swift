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

    private let bottomBarHeight: CGFloat = 42

    var body: some View {
        ZStack {
            // Match the app’s general background style
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                mainContent

                NowPlayingBottomBar(
                    slideshowTitle: nowPlayingStore.activeSlideshow?.title,
                    trackTitle: playbackBridge.currentTrackTitle,
                    trackArtist: playbackBridge.currentTrackArtist,
                    isSlideshowPlaying: playbackBridge.isSlideshowPlaying,
                    isMusicPlaying: playbackBridge.isMusicPlaying
                )
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

    private var hasPreviousSlide: Bool {
        guard hasSlides else { return false }
        return playbackBridge.currentSlideIndex > 0
    }

    private var hasNextSlide: Bool {
        guard hasSlides else { return false }
        return playbackBridge.currentSlideIndex < max(0, playbackBridge.totalSlides - 1)
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

    private func clipLengthLabel(for mode: MusicClipMode) -> String {
        switch mode {
        case .seconds30:
            return "30s"
        case .seconds45:
            return "45s"
        case .seconds60:
            return "60s"
        case .fullSong:
            return "Full"
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
                hasPrevious: hasPreviousSlide,
                hasNext: hasNextSlide,
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
            .sidebarCardStyle()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Sidebar.cornerRadius)
                    .fill(
                        playbackBridge.isMusicPlaying
                        ? Color.accentColor.opacity(0.12)
                        : AppTheme.Sidebar.cardBackground
                    )
            )
            .overlay(alignment: .trailing) {
                if playbackBridge.isMusicPlaying {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .padding(.trailing, 6)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: playbackBridge.isMusicPlaying)

            // Clip length control – styled as part of the music controls
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Clip length")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if playbackBridge.isMusicPlaying {
                        Text("per track")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("", selection: Binding(
                    get: { playbackBridge.clipMode },
                    set: { newValue in
                        playbackBridge.clipMode = newValue
                        playbackBridge.onClipModeChanged?(newValue)
                    }
                )) {
                    ForEach(MusicClipMode.allCases) { mode in
                        Text(clipLengthLabel(for: mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
            }
            .sidebarCardStyle()
            .animation(.easeInOut(duration: 0.2), value: playbackBridge.clipMode)

            // Shuffle / Repeat controls
            HStack(spacing: 12) {
                SidebarToggleIconButton(
                    systemName: "shuffle",
                    label: "Shuffle",
                    isActive: playbackBridge.isShuffleEnabled
                ) {
                    playbackBridge.toggleShuffle?()
                }

                SidebarToggleIconButton(
                    systemName: "repeat",
                    label: "Repeat",
                    isActive: playbackBridge.isRepeatAllEnabled
                ) {
                    playbackBridge.toggleRepeatAll?()
                }
            }
            .padding(.top, 4)

            // Controls group: secondary transport row
            MusicTransportControlsRow(
                isPlaying: playbackBridge.isMusicPlaying,
                onPrevious: { playbackBridge.musicPreviousTrack?() },
                onPlayPause: { playbackBridge.musicTogglePlayPause?() },
                onNext: { playbackBridge.musicNextTrack?() }
            )

            Spacer()
        }
        .padding(AppTheme.Sidebar.horizontalPadding)
        .frame(width: sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Sidebar.cornerRadius)
                .fill(AppTheme.Sidebar.panelBackground)
                .shadow(radius: 2, x: 0, y: -1)
        )
        .padding(.leading, 12)
    }
}

private struct SidebarToggleIconButton: View {
    let systemName: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isActive ? Color.accentColor : Color.secondary.opacity(0.4),
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

// Small, reusable "SLIDESHOW" / "MUSIC" style label
private struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .sidebarSectionHeaderStyle()
    }
}

// Primary "media transport" row – used for the slideshow
private struct SlideshowTransportControlsRow: View {
    let isPlaying: Bool
    let hasPrevious: Bool
    let hasNext: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPrevious) {
                Image(systemName: "backward.end.fill")
                    .font(.title2)
                    .opacity(hasPrevious ? 1.0 : 0.35)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!hasPrevious)

            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(minWidth: 34, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isPlaying ? .accentColor : .primary) // “alive” vs calm
            .disabled(!hasPrevious && !hasNext)        // no slides at all

            Button(action: onNext) {
                Image(systemName: "forward.end.fill")
                    .font(.title2)
                    .opacity(hasNext ? 1.0 : 0.35)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!hasNext)
        }
        .sidebarHoverRow(isHovering: isHovering)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
    }
}

// Secondary transport row – visually lighter, used for music
private struct MusicTransportControlsRow: View {
    let isPlaying: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    @State private var isHovering = false

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
        .sidebarHoverRow(isHovering: isHovering)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
    }
}

// MARK: - Bottom status bar

struct NowPlayingBottomBar: View {
    let slideshowTitle: String?
    let trackTitle: String?
    let trackArtist: String?
    let isSlideshowPlaying: Bool
    let isMusicPlaying: Bool

    private var statusText: String {
        let slideshow = (slideshowTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let track = (trackTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        switch (slideshow.isEmpty, track.isEmpty) {
        case (true, true):
            return "Ready when you are — start a slideshow on the left."
        case (false, true):
            return "Now Playing: \(slideshow)"
        case (true, false):
            return "Now Playing: \(track)"
        case (false, false):
            return "Now Playing: \(slideshow) — \(track)"
        }
    }

    private var secondaryHint: String {
        "Playback controls are in the sidebar →"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left: compact status with subtle play indicators
            HStack(spacing: 6) {
                // Slideshow indicator
                if !statusText.isEmpty {
                    Image(systemName: isSlideshowPlaying ? "play.circle.fill" : "pause.circle")
                        .imageScale(.small)
                        .foregroundColor(isSlideshowPlaying ? .accentColor : .secondary)
                        .opacity(0.9)
                }

                Text(statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Right: hint aligned under the sidebar
            HStack(spacing: 4) {
                if isMusicPlaying {
                    Image(systemName: "waveform")
                        .imageScale(.small)
                }

                Text(secondaryHint)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .opacity(0.96)
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.black.opacity(0.2)),
            alignment: .top
        )
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(NowPlayingStore())
}
