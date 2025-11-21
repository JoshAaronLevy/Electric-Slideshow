//
//  PhotoLibraryService.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation
internal import Photos
import AppKit
import Combine

/// Service responsible for all PhotoKit interactions
/// Uses PHCachingImageManager for optimized thumbnail loading
@MainActor
final class PhotoLibraryService: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined {
        didSet {
            print("🔍 PhotoLibraryService: authorizationStatus changed from \(oldValue.rawValue) to \(authorizationStatus.rawValue)")
        }
    }
    
    private let cachingImageManager = PHCachingImageManager()
    
    init() {
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        configureCachingManager()
    }
    
    // MARK: - Configuration
    
    private func configureCachingManager() {
        // Allow a reasonable cache size for smooth scrolling
        cachingImageManager.allowsCachingHighQualityImages = false
    }
    
    // MARK: - Authorization
    
    /// Get the current authorization status
    func currentAuthorizationStatus() -> PHAuthorizationStatus {
        return authorizationStatus
    }
    
    /// Request permission to access the photo library
    @MainActor
    func requestAuthorization() async -> Bool {
        print("🔍 PhotoLibraryService: Starting requestAuthorization()")
        print("🔍 PhotoLibraryService: Current authorization status before request: \(authorizationStatus.rawValue)")
        print("🔍 PhotoLibraryService: Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("🔍 PhotoLibraryService: About to call PHPhotoLibrary.requestAuthorization(for: .readWrite)")
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        
        print("🔍 PhotoLibraryService: PHPhotoLibrary.requestAuthorization() completed")
        print("🔍 PhotoLibraryService: New authorization status: \(status.rawValue)")
        
        authorizationStatus = status
        
        let result = status == .authorized || status == .limited
        print("🔍 PhotoLibraryService: requestAuthorization() returning: \(result)")
        return result
    }
    
    // MARK: - Fetching Albums & Assets
    
    /// Fetch all albums (smart albums + user albums)
    func fetchAlbums() async throws -> [Album] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotoLibraryError.notAuthorized
        }
        
        return await withCheckedContinuation { continuation in
            var albums: [Album] = []
            
            // Fetch smart albums
            let smartAlbums = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .albumRegular,
                options: nil
            )
            smartAlbums.enumerateObjects { collection, _, _ in
                let album = Album(collection: collection)
                if album.assetCount > 0 {
                    albums.append(album)
                }
            }
            
            // Fetch user albums
            let userAlbums = PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .albumRegular,
                options: nil
            )
            userAlbums.enumerateObjects { collection, _, _ in
                let album = Album(collection: collection)
                if album.assetCount > 0 {
                    albums.append(album)
                }
            }
            
            continuation.resume(returning: albums)
        }
    }
    
    /// Fetch assets from a specific album
    func fetchAssets(in album: Album) async throws -> [PhotoAsset] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotoLibraryError.notAuthorized
        }
        
        return await withCheckedContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let assets = PHAsset.fetchAssets(in: album.collection, options: fetchOptions)
            var photoAssets: [PhotoAsset] = []
            
            assets.enumerateObjects { asset, _, _ in
                if asset.mediaType == .image {
                    photoAssets.append(PhotoAsset(asset: asset))
                }
            }
            
            continuation.resume(returning: photoAssets)
        }
    }
    
    // MARK: - Image Loading
    
    /// Load thumbnail image for a photo asset
    /// This method can be called concurrently for multiple assets
    func thumbnail(for photoAsset: PhotoAsset, size: CGSize) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            cachingImageManager.requestImage(
                for: photoAsset.asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                // PHImageManager can call this completion handler multiple times
                // (first with low-quality, then with high-quality image)
                // Only resume the continuation on the first call
                guard !hasResumed else { return }
                hasResumed = true
                
                // `image` is already an NSImage? on macOS
                if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Load full-size or preview image for a photo asset
    func image(for photoAsset: PhotoAsset, size: CGSize) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            let targetSize = size == ImageSize.fullSize ? PHImageManagerMaximumSize : size
            
            cachingImageManager.requestImage(
                for: photoAsset.asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Caching Management
    
    /// Start caching images for the given assets
    /// This preheats the cache for smooth scrolling
    func startCaching(for assets: [PhotoAsset], size: CGSize) {
        let phAssets = assets.map { $0.asset }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        
        cachingImageManager.startCachingImages(
            for: phAssets,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        )
    }
    
    /// Stop caching images for the given assets
    func stopCaching(for assets: [PhotoAsset], size: CGSize) {
        let phAssets = assets.map { $0.asset }
        cachingImageManager.stopCachingImages(
            for: phAssets,
            targetSize: size,
            contentMode: .aspectFill,
            options: nil
        )
    }
    
    /// Stop all caching
    func stopCachingAllImages() {
        cachingImageManager.stopCachingImagesForAllAssets()
    }
}
