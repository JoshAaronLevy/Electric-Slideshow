//
//  NowPlayingView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/26/25.
//

import SwiftUI

/// Main Now Playing screen that will host slideshow + music playback
struct NowPlayingView: View {
    var body: some View {
        ZStack {
            // Match the app’s general background style
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            ContentUnavailableView {
                Label("Nothing Playing", systemImage: "play.circle")
            } description: {
                Text("No slideshow is currently playing. Go to Slideshows to create or start one.")
            }
        }
    }
}

#Preview {
    NowPlayingView()
}
