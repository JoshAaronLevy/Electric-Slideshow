//
//  Electric_SlideshowApp.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

internal import SwiftUI

@main
struct Electric_SlideshowApp: App {
    @StateObject private var photoService = PhotoLibraryService()
    @StateObject private var spotifyAuthService = SpotifyAuthService.shared
    @StateObject private var playlistsStore = PlaylistsStore()
    
    var body: some Scene {
        WindowGroup {
            AppShellView(photoService: photoService)
                .environmentObject(photoService)
                .environmentObject(spotifyAuthService)
                .environmentObject(playlistsStore)
                .onOpenURL { url in
                    // Handle OAuth callback
                    if url.scheme == "com.slideshowbuddy" {
                        Task {
                            await spotifyAuthService.handleCallback(url: url)
                        }
                    }
                }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
