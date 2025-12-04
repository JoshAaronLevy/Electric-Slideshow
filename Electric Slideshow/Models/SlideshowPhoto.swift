//
//  SlideshowPhoto.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation

/// Lightweight reference to a photo asset in the slideshow
struct SlideshowPhoto: Codable, Equatable, Identifiable {
    /// Unique identifier for this photo in the slideshow
    let id: String
    
    /// PhotoKit local identifier for fetching the actual asset
    let localIdentifier: String
    
    init(id: String = UUID().uuidString, localIdentifier: String) {
        self.id = id
        self.localIdentifier = localIdentifier
    }
}
