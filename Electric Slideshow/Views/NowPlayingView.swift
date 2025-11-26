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

    var body: some View {
        ZStack {
            // Match the app’s general background style
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            if let slideshow = nowPlayingStore.activeSlideshow {
                // Placeholder for future full playback UI
                VStack(spacing: 12) {
                    Text("Now Playing")
                        .font(.title)
                        .fontWeight(.semibold)

                    Text(slideshow.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Empty state when nothing is playing
                ContentUnavailableView {
                    Label("Nothing Playing", systemImage: "play.circle")
                } description: {
                    Text("No slideshow is currently playing. Go to Slideshows to create or start one.")
                }
            }
        }
    }
}

#Preview {
    let store = NowPlayingStore()
    return NowPlayingView()
        .environmentObject(store)
}
