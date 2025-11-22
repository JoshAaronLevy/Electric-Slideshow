//
//  PhotoLibraryViewModel.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation
import Photos
import Combine

/// Manages photo library browsing and selection for slideshow creation
@MainActor
class PhotoLibraryViewModel: ObservableObject {
    @Published var albums: [Album] = []
    @Published var selectedAlbum: Album?
    @Published var assets: [PhotoAsset] = []
    @Published var selectedAssetIds: Set<String> = []
    @Published var isLoadingAlbums = false
    @Published var isLoadingAssets = false
    
    private let photoService: PhotoLibraryService
    
    /// Number of selected photos
    var selectedCount: Int {
        selectedAssetIds.count
    }
    
    init(photoService: PhotoLibraryService) {
        self.photoService = photoService
    }
    
    /// Load all albums from the photo library
    func loadAlbums() async {
        isLoadingAlbums = true
        defer { isLoadingAlbums = false }
        
        do {
            albums = try await photoService.fetchAlbums()
            
            // Auto-select first album if available
            if selectedAlbum == nil, let firstAlbum = albums.first {
                await selectAlbum(firstAlbum)
            }
        } catch {
            print("Error loading albums: \(error.localizedDescription)")
            albums = []
        }
    }
    
    /// Select an album and load its assets
    func selectAlbum(_ album: Album) async {
        selectedAlbum = album
        await loadAssets(for: album)
    }
    
    /// Load assets for a specific album
    private func loadAssets(for album: Album) async {
        isLoadingAssets = true
        defer { isLoadingAssets = false }
        
        do {
            assets = try await photoService.fetchAssets(in: album)
        } catch {
            print("Error loading assets: \(error.localizedDescription)")
            assets = []
        }
    }
    
    /// Toggle selection state for an asset
    func toggleSelection(for asset: PhotoAsset) {
        if selectedAssetIds.contains(asset.id) {
            selectedAssetIds.remove(asset.id)
        } else {
            selectedAssetIds.insert(asset.id)
        }
    }
    
    /// Check if an asset is selected
    func isSelected(_ asset: PhotoAsset) -> Bool {
        selectedAssetIds.contains(asset.id)
    }
    
    /// Clear all selections
    func clearSelection() {
        selectedAssetIds.removeAll()
    }
    
    /// Select all assets in current album
    func selectAll() {
        selectedAssetIds = Set(assets.map { $0.id })
    }
}
