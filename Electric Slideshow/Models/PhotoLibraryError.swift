//
//  PhotoLibraryError.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation

/// Errors that can occur when interacting with the photo library
enum PhotoLibraryError: LocalizedError {
    case notAuthorized
    case fetchFailed
    case imageLoadFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Photo library access is not authorized. Please grant permission in System Settings."
        case .fetchFailed:
            return "Failed to fetch items from the photo library."
        case .imageLoadFailed:
            return "Failed to load image."
        }
    }
}
