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
    @StateObject private var internalPlayerManager = InternalPlayerManager()
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        Window("Electric Slideshow", id: "mainWindow") {
            AppShellView(photoService: photoService)
                .environmentObject(photoService)
                .environmentObject(spotifyAuthService)
                .environmentObject(playlistsStore)
                .environmentObject(nowPlayingStore)
                .environmentObject(internalPlayerManager)
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
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .background {
                        // Stop internal player when app goes to background or quits
                        print("[App] Scene phase changed to background, stopping internal player")
                        internalPlayerManager.stop()
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
