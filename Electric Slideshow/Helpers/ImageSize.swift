//
//  ImageSize.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation

/// Standard image sizes used throughout the app
enum ImageSize {
    /// Thumbnail size for grid display (200x200 points, 2x scale for retina)
    static let thumbnail = CGSize(width: 400, height: 400)
    
    /// Preview size for detail view
    static let preview = CGSize(width: 1200, height: 1200)
    
    /// Full resolution (use PHImageManagerMaximumSize)
    static var fullSize: CGSize {
        return CGSize(width: CGFloat(Int.max), height: CGFloat(Int.max))
    }
}
