//
//  PhotoGridViewModel.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation
import AppKit
import Observation

/// ViewModel for the photo grid view
@MainActor
@Observable
class PhotoGridViewModel {
    var photos: [PhotoAsset] = []
    var thumbnails: [String: NSImage] = [:] // keyed by asset ID
    var isLoading = false
    var selectedAlbum: Album?
    
    private let photoService: PhotoLibraryService
    
    init(photoService: PhotoLibraryService) {
        self.photoService = photoService
    }
    
    /// Load photos from the selected album
    func loadPhotos(from album: Album) async {
        selectedAlbum = album
        isLoading = true
        
        photos = await photoService.fetchPhotos(from: album)
        isLoading = false
        
        // Start loading thumbnails
        await loadThumbnails()
    }
    
    /// Load thumbnails for all photos
    private func loadThumbnails() async {
        let thumbnailSize = CGSize(width: 200, height: 200)
        
        for photo in photos {
            if let thumbnail = await photoService.loadThumbnail(for: photo, size: thumbnailSize) {
                thumbnails[photo.id] = thumbnail
            }
        }
    }
    
    /// Get thumbnail for a specific photo
    func thumbnail(for photo: PhotoAsset) -> NSImage? {
        return thumbnails[photo.id]
    }
    
    /// Clear current selection
    func clearSelection() {
        selectedAlbum = nil
        photos = []
        thumbnails = [:]
    }
}
