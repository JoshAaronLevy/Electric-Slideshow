//
//  AppNavigationBar.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Custom top navigation bar for the app
struct AppNavigationBar: View {
    let appTitleTop: String
    let appTitleBottom: String
    let currentSectionTitle: String
    let sections: [AppSection]
    let selectedSection: AppSection
    let onSectionSelected: (AppSection) -> Void
    let onUserIconTapped: () -> Void

    @EnvironmentObject private var spotifyAuthService: SpotifyAuthService
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: App logo and stacked app name
            HStack(spacing: 8) {
                // App logo
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                
                // Stacked app name
                appTitleView
            }
            .frame(minWidth: 100, alignment: .leading)
            
            Spacer(minLength: 20)
            
            // Center: Current section title
            Text(currentSectionTitle)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: 300)
            
            Spacer(minLength: 20)
            
            // Right: Navigation icons
            navigationIcons
                .frame(minWidth: 100, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(height: 56)
        .frame(minWidth: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }
    
    // MARK: - App Title
    
    private var appTitleView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(appTitleTop)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text(appTitleBottom)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(height: 32)
    }
    
    // MARK: - Navigation Icons
    
    private var navigationIcons: some View {
        HStack(spacing: 6) {
            ForEach(sections) { section in
                navigationButton(for: section)
            }
        }
    }
    
    private func navigationButton(for section: AppSection) -> some View {
        let isSelected = selectedSection == section
        let showSpotifyWarning = (section == .music && !spotifyAuthService.isAuthenticated)

        return Button {
            if section == .user {
                onUserIconTapped()
            } else {
                onSectionSelected(section)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: section.systemImageName)
                    .font(.system(size: 17))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                    )
                    .contentShape(Rectangle())

                if showSpotifyWarning {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .help(section.title)
        .pointingHandCursor()
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview("Slideshows Selected") {
    VStack(spacing: 0) {
        AppNavigationBar(
            appTitleTop: "Electric",
            appTitleBottom: "Slideshow",
            currentSectionTitle: "Slideshows",
            sections: [.nowPlaying, .slideshows, .music, .settings, .user],
            selectedSection: .slideshows,
            onSectionSelected: { _ in },
            onUserIconTapped: { }
        )
        Spacer()
    }
    .frame(width: 800, height: 600)
}

#Preview("Playlists Selected") {
    VStack(spacing: 0) {
        AppNavigationBar(
            appTitleTop: "Electric",
            appTitleBottom: "Slideshow",
            currentSectionTitle: "Playlists",
            sections: [.nowPlaying, .slideshows, .music, .settings, .user],
            selectedSection: .music,
            onSectionSelected: { _ in },
            onUserIconTapped: { }
        )
        Spacer()
    }
    .frame(width: 800, height: 600)
}

#Preview("Dark Mode") {
    VStack(spacing: 0) {
        AppNavigationBar(
            appTitleTop: "Electric",
            appTitleBottom: "Slideshow",
            currentSectionTitle: "Settings",
            sections: [.nowPlaying, .slideshows, .music, .settings, .user],
            selectedSection: .settings,
            onSectionSelected: { _ in },
            onUserIconTapped: { }
        )
        Spacer()
    }
    .frame(width: 800, height: 600)
    .preferredColorScheme(.dark)
}

#Preview("Narrow Window") {
    VStack(spacing: 0) {
        AppNavigationBar(
            appTitleTop: "Electric",
            appTitleBottom: "Slideshow",
            currentSectionTitle: "Slideshows",
            sections: [.nowPlaying, .slideshows, .music, .settings, .user],
            selectedSection: .slideshows,
            onSectionSelected: { _ in },
            onUserIconTapped: { }
        )
        Spacer()
    }
    .frame(width: 600, height: 400)
}

#Preview("Wide Window") {
    VStack(spacing: 0) {
        AppNavigationBar(
            appTitleTop: "Electric",
            appTitleBottom: "Slideshow",
            currentSectionTitle: "Playlists",
            sections: [.nowPlaying, .slideshows, .music, .settings, .user],
            selectedSection: .music,
            onSectionSelected: { _ in },
            onUserIconTapped: { }
        )
        Spacer()
    }
    .frame(width: 1200, height: 800)
}
