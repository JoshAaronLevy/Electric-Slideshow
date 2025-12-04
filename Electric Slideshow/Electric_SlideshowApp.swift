//
//  Electric_SlideshowApp.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

@main
struct Electric_SlideshowApp: App {
    @StateObject private var photoService = PhotoLibraryService()
    @StateObject private var spotifyAuthService = SpotifyAuthService.shared
    @StateObject private var playlistsStore = PlaylistsStore()
    @StateObject private var nowPlayingStore = NowPlayingStore()
    
    var body: some Scene {
        Window("Electric Slideshow", id: "mainWindow") {
            AppShellView(photoService: photoService)
                .environmentObject(photoService)
                .environmentObject(spotifyAuthService)
                .environmentObject(playlistsStore)
                .environmentObject(nowPlayingStore)
                .onOpenURL { url in
                    print("[App] ===== onOpenURL CALLED =====")
                    print("[App] URL: \(url.absoluteString)")
                    print("[App] Scheme: \(url.scheme ?? "nil")")

                    // Handle OAuth callback
                    if url.scheme == "com.electricslideshow" {
                        print("[App] Scheme matches, calling handleCallback")
                        Task {
                            await spotifyAuthService.handleCallback(url: url)
                        }
                    } else {
                        print("[App] Scheme does not match com.electricslideshow")
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
