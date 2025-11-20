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
    
    var body: some Scene {
        WindowGroup {
            AppShellView(photoService: photoService)
                .environmentObject(photoService)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
