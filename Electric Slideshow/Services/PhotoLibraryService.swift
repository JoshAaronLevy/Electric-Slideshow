//
//  PhotoLibraryService.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation
import Photos
import AppKit

/// Service responsible for all PhotoKit interactions
@MainActor
class PhotoLibraryService: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    private let imageManager = PHImageManager.default()
    
    init() {
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    /// Request permission to access the photo library
    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        return status == .authorized || status == .limited
    }
    
    /// Fetch all albums (smart albums + user albums)
    func fetchAlbums() async -> [Album] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return []
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
    
    /// Fetch photos from a specific album
    func fetchPhotos(from album: Album) async -> [PhotoAsset] {
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
    
    /// Load thumbnail image for a photo asset
    func loadThumbnail(for photoAsset: PhotoAsset, size: CGSize) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            
            imageManager.requestImage(
                for: photoAsset.asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let cgImage = image {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    continuation.resume(returning: nsImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Load full-size image for a photo asset (placeholder implementation)
    func loadFullImage(for photoAsset: PhotoAsset) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            imageManager.requestImage(
                for: photoAsset.asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                if let cgImage = image {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    continuation.resume(returning: nsImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
