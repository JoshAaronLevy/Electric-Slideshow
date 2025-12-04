//
//  AppSection.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation

/// Represents the primary navigation sections of the app
enum AppSection: String, CaseIterable, Identifiable {
    case nowPlaying
    case slideshows
    case music
    case settings
    case user

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlaying: return "Now Playing"
        case .slideshows: return "Slideshows"
        case .music: return "Playlists"
        case .settings: return "Settings"
        case .user: return "User"
        }
    }

    var systemImageName: String {
        switch self {
        case .nowPlaying: return "play.circle"
        case .slideshows: return "photo.on.rectangle"
        case .music: return "music.note"
        case .settings: return "gearshape"
        case .user: return "person.crop.circle"
        }
    }
}
