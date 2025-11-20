//
//  AlbumListViewModel.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation
import Observation

/// ViewModel for the album list sidebar
@MainActor
@Observable
class AlbumListViewModel {
    var albums: [Album] = []
    var isLoading = false
    var errorMessage: String?
    
    private let photoService: PhotoLibraryService
    
    init(photoService: PhotoLibraryService) {
        self.photoService = photoService
    }
    
    /// Load all albums from the photo library
    func loadAlbums() async {
        isLoading = true
        errorMessage = nil
        
        do {
            albums = await photoService.fetchAlbums()
            isLoading = false
        } catch {
            errorMessage = "Failed to load albums: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Request photo library authorization
    func requestAuthorization() async {
        let granted = await photoService.requestAuthorization()
        if granted {
            await loadAlbums()
        } else {
            errorMessage = "Photo library access denied. Please grant permission in System Settings."
        }
    }
}
