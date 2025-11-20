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
    var loadingProgress: Double = 0.0
    var error: PhotoLibraryError?
    
    private let photoService: PhotoLibraryService
    private var loadingTask: Task<Void, Never>?
    
    init(photoService: PhotoLibraryService) {
        self.photoService = photoService
    }
    
    /// Load photos from the selected album
    func loadPhotos(from album: Album) async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Clear previous state and stop caching
        stopCaching()
        photos = []
        thumbnails = [:]
        error = nil
        loadingProgress = 0.0
        
        isLoading = true
        
        do {
            // Fetch assets
            photos = try await photoService.fetchAssets(in: album)
            isLoading = false
            
            // Start caching for smooth scrolling
            startCaching()
            
            // Load thumbnails concurrently
            loadingTask = Task {
                await loadThumbnails()
            }
        } catch let photoError as PhotoLibraryError {
            error = photoError
            isLoading = false
        } catch {
            error = .fetchFailed
            isLoading = false
        }
    }
    
    /// Load thumbnails for all photos concurrently
    private func loadThumbnails() async {
        let thumbnailSize = ImageSize.thumbnail
        let totalPhotos = photos.count
        guard totalPhotos > 0 else { return }
        
        // Load thumbnails concurrently in batches to avoid memory pressure
        let batchSize = 20
        
        for startIndex in stride(from: 0, to: totalPhotos, by: batchSize) {
            let endIndex = min(startIndex + batchSize, totalPhotos)
            let batch = Array(photos[startIndex..<endIndex])
            
            // Check if task was cancelled
            if Task.isCancelled { return }
            
            // Load batch concurrently
            await withTaskGroup(of: (String, NSImage?).self) { group in
                for photo in batch {
                    group.addTask {
                        let image = await self.photoService.thumbnail(for: photo, size: thumbnailSize)
                        return (photo.id, image)
                    }
                }
                
                // Collect results and update UI
                for await (id, image) in group {
                    if let image = image {
                        thumbnails[id] = image
                    }
                    
                    // Update progress
                    loadingProgress = Double(thumbnails.count) / Double(totalPhotos)
                }
            }
        }
    }
    
    /// Get thumbnail for a specific photo
    func thumbnail(for photo: PhotoAsset) -> NSImage? {
        return thumbnails[photo.id]
    }
    
    /// Start caching thumbnails for visible assets
    private func startCaching() {
        guard !photos.isEmpty else { return }
        // Cache first batch for immediate display
        let initialBatch = Array(photos.prefix(40))
        photoService.startCaching(for: initialBatch, size: ImageSize.thumbnail)
    }
    
    /// Stop caching when switching albums
    private func stopCaching() {
        guard !photos.isEmpty else { return }
        photoService.stopCachingAllImages()
    }
    
    /// Clear current selection and stop any loading
    func clearSelection() {
        loadingTask?.cancel()
        stopCaching()
        photos = []
        thumbnails = [:]
        error = nil
        loadingProgress = 0.0
    }
    
    /// Computed property for error message display
    var errorMessage: String? {
        error?.errorDescription
    }
}
