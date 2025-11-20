//
//  Slideshow.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation

/// A saved slideshow configuration
struct Slideshow: Codable, Equatable, Identifiable {
    /// Unique identifier
    let id: UUID
    
    /// User-provided title for the slideshow
    var title: String
    
    /// Photos included in this slideshow
    var photos: [SlideshowPhoto]
    
    /// Playback settings
    var settings: SlideshowSettings
    
    /// Creation timestamp
    let createdAt: Date
    
    /// Computed property for photo count
    var photoCount: Int {
        photos.count
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        photos: [SlideshowPhoto],
        settings: SlideshowSettings = .default,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.photos = photos
        self.settings = settings
        self.createdAt = createdAt
    }
}
