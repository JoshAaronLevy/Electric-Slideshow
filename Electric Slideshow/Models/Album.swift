//
//  Album.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation
import Photos

/// Represents a photo album from the user's library
struct Album: Identifiable, Hashable {
    let id: String
    let title: String
    let assetCount: Int
    let collection: PHAssetCollection
    
    init(collection: PHAssetCollection) {
        self.id = collection.localIdentifier
        self.title = collection.localizedTitle ?? "Untitled Album"
        self.assetCount = PHAsset.fetchAssets(in: collection, options: nil).count
        self.collection = collection
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id
    }
}
