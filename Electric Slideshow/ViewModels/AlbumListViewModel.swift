//
//  AlbumListViewModel.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation
import Observation
import Combine

/// ViewModel for the album list sidebar
@MainActor
@Observable
class AlbumListViewModel {
    var albums: [Album] = []
    var isLoading = false
    var error: PhotoLibraryError?
    
    private let photoService: PhotoLibraryService
    
    init(photoService: PhotoLibraryService) {
        self.photoService = photoService
    }
    
    /// Load all albums from the photo library
    func loadAlbums() async {
        isLoading = true
        error = nil
        
        do {
            albums = try await photoService.fetchAlbums()
            isLoading = false
        } catch let photoError as PhotoLibraryError {
            error = photoError
            isLoading = false
        } catch {
            self.error = .fetchFailed
            isLoading = false
        }
    }
    
    /// Request photo library authorization and load albums if granted
    func requestAuthorization() async {
        let granted = await photoService.requestAuthorization()
        if granted {
            await loadAlbums()
        } else {
            error = .notAuthorized
        }
    }
    
    /// Computed property for error message display
    var errorMessage: String? {
        error?.errorDescription
    }
}
