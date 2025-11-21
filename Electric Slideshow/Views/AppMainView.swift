//
//  AppMainView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Root main content view that manages section navigation
struct AppMainView: View {
    @State private var selectedSection: AppSection = .slideshows
    
    var body: some View {
        VStack(spacing: 0) {
            // Top: Navigation Bar
            AppNavigationBar(
                appTitleTop: "Electric",
                appTitleBottom: "Slideshow",
                currentSectionTitle: selectedSection.title,
                sections: [.slideshows, .music, .settings, .user],
                selectedSection: selectedSection,
                onSectionSelected: { section in
                    handleSectionSelection(section)
                }
            )
            
            // Bottom: Section Content
            ZStack {
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
    
    // MARK: - Navigation Handling
    
    private func handleSectionSelection(_ section: AppSection) {
        // For now, all sections can be selected
        // User icon behavior can be customized later if needed
        selectedSection = section
    }
}

#Preview {
    AppMainView()
        .environmentObject(PhotoLibraryService())
}
