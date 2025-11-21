//
//  PlaceholderViews.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

internal import SwiftUI

/// Placeholder view for the Music section
struct MusicPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            
            Text("Music view loaded!")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("This section is coming soon.")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Placeholder view for the Settings section
struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            
            Text("Settings view loaded!")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("This section is coming soon.")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Placeholder view for the User section
struct UserPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            
            Text("User view loaded!")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("This section is coming soon.")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Music") {
    MusicPlaceholderView()
}

#Preview("Settings") {
    SettingsPlaceholderView()
}

#Preview("User") {
    UserPlaceholderView()
}
