//
//  AppMainView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Root main content view that manages section navigation
/// Stage 1: Basic shell with section switching (navigation bar will be added in Stage 2)
struct AppMainView: View {
    @State private var selectedSection: AppSection = .slideshows
    
    var body: some View {
        ZStack {
            // Section content
            switch selectedSection {
            case .slideshows:
                SlideshowsListView()
            case .music:
                MusicPlaceholderView()
            case .settings:
                SettingsPlaceholderView()
            case .user:
                UserPlaceholderView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AppMainView()
        .environmentObject(PhotoLibraryService())
}
