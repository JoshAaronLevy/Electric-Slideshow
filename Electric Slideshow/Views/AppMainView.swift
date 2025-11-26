//
//  AppMainView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Root main content view that manages section navigation
struct AppMainView: View {
    @State private var selectedSection: AppSection = .nowPlaying
    @State private var showingUserProfile = false
    @StateObject private var devicesViewModel = SpotifyDevicesViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top: Navigation Bar
            AppNavigationBar(
                appTitleTop: "Electric",
                appTitleBottom: "Slideshow",
                currentSectionTitle: selectedSection.title,
                sections: [.nowPlaying, .slideshows, .music, .settings, .user],
                selectedSection: selectedSection,
                onSectionSelected: { section in
                    handleSectionSelection(section)
                },
                onUserIconTapped: {
                    showingUserProfile = true
                }
            )
            
            // Bottom: Section Content
            ZStack {
                switch selectedSection {
                case .nowPlaying:
                    NowPlayingView()
                case .slideshows:
                    SlideshowsListView()
                case .music:
                    PlaylistsView()
                case .settings:
                    SettingsDashboardView(devicesViewModel: devicesViewModel)
                case .user:
                    UserPlaceholderView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingUserProfile) {
            UserProfileModal()
        }
    }
    
    // MARK: - Navigation Handling
    
    private func handleSectionSelection(_ section: AppSection) {
        switch section {
        case .user:
            // TODO: Will trigger a user profile modal in the future
            // For now, do nothing - user icon doesn't change sections
            break
        default:
            // Switch to the selected section
            selectedSection = section
        }
    }
}

#Preview {
    AppMainView()
        .environmentObject(PhotoLibraryService())
}
