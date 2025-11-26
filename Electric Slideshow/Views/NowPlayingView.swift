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

    private let bottomBarHeight: CGFloat = 56  // Match AppNavigationBar height

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
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if let slideshow = nowPlayingStore.activeSlideshow {
            // Placeholder area where the slideshow will eventually render.
            // For now, just show the title centered to confirm layout works.
            ZStack {
                Color.black
                    .ignoresSafeArea(edges: .horizontal)

                VStack(spacing: 12) {
                    Text("Now Playing")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text(slideshow.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
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
                        // previous slide (to be wired later)
                    } label: {
                        Image(systemName: "backward.end.fill")
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)

                    Button {
                        // play/pause (to be wired later)
                    } label: {
                        Image(systemName: "playpause.fill")
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)

                    Button {
                        // next slide (to be wired later)
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

                // Right: Music / track info area (placeholder for now)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No track playing")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Spotify")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        // previous track (to be wired later)
                    } label: {
                        Image(systemName: "backward.fill")
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)

                    Button {
                        // play/pause track (to be wired later)
                    } label: {
                        Image(systemName: "playpause.fill")
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)

                    Button {
                        // next track (to be wired later)
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)
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
