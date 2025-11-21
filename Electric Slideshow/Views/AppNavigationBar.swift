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
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: Stacked app name
            appTitleView
                .frame(minWidth: 120)
            
            Spacer()
            
            // Center: Current section title
            Text(currentSectionTitle)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Right: Navigation icons
            navigationIcons
                .frame(minWidth: 120)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(height: 56)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }
    
    // MARK: - App Title
    
    private var appTitleView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(appTitleTop)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text(appTitleBottom)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Navigation Icons
    
    private var navigationIcons: some View {
        HStack(spacing: 8) {
            ForEach(sections) { section in
                navigationButton(for: section)
            }
        }
    }
    
    private func navigationButton(for section: AppSection) -> some View {
        Button {
            onSectionSelected(section)
        } label: {
            Image(systemName: section.systemImageName)
                .font(.system(size: 18))
                .foregroundStyle(selectedSection == section ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    selectedSection == section
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(section.title)
    }
}

#Preview("Slideshows Selected") {
    AppNavigationBar(
        appTitleTop: "Electric",
        appTitleBottom: "Slideshow",
        currentSectionTitle: "Slideshows",
        sections: [.slideshows, .music, .settings, .user],
        selectedSection: .slideshows,
        onSectionSelected: { _ in }
    )
    .frame(width: 800)
}

#Preview("Music Selected") {
    AppNavigationBar(
        appTitleTop: "Electric",
        appTitleBottom: "Slideshow",
        currentSectionTitle: "Music",
        sections: [.slideshows, .music, .settings, .user],
        selectedSection: .music,
        onSectionSelected: { _ in }
    )
    .frame(width: 800)
}

#Preview("Dark Mode") {
    AppNavigationBar(
        appTitleTop: "Electric",
        appTitleBottom: "Slideshow",
        currentSectionTitle: "Settings",
        sections: [.slideshows, .music, .settings, .user],
        selectedSection: .settings,
        onSectionSelected: { _ in }
    )
    .frame(width: 800)
    .preferredColorScheme(.dark)
}
