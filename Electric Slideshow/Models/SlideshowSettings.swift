//
//  SlideshowSettings.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation

/// Configuration settings for a slideshow
struct SlideshowSettings: Codable, Equatable {
    /// Duration each photo is displayed (in seconds)
    var durationPerSlide: TimeInterval
    
    /// Whether photos should be displayed in random order
    var shuffle: Bool
    
    /// Whether the slideshow should loop continuously
    var repeatEnabled: Bool
    
    /// Optional linked app playlist for background music
    var linkedPlaylistId: UUID?
    
    /// Default settings
    static let `default` = SlideshowSettings(
        durationPerSlide: 3.0,
        shuffle: false,
        repeatEnabled: true,
        linkedPlaylistId: nil
    )
}
