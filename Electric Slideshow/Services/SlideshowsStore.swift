//
//  SlideshowsStore.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation

/// Simple persistence service for slideshows
/// Uses JSON file in application support directory
class SlideshowsStore {
    private let fileManager = FileManager.default
    private let fileName = "slideshows.json"
    
    /// Get the file URL for slideshows storage
    private var fileURL: URL {
        get throws {
            let appSupportDir = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let bundleID = Bundle.main.bundleIdentifier ?? "com.electricslideshow"
            let appDir = appSupportDir.appendingPathComponent(bundleID, isDirectory: true)
            
            // Create app directory if it doesn't exist
            if !fileManager.fileExists(atPath: appDir.path) {
                try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            }
            
            return appDir.appendingPathComponent(fileName)
        }
    }
    
    /// Load slideshows from persistent storage
    func loadSlideshows() -> [Slideshow] {
        do {
            let url = try fileURL
            
            // If file doesn't exist, return empty array
            guard fileManager.fileExists(atPath: url.path) else {
                return []
            }
            
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let slideshows = try decoder.decode([Slideshow].self, from: data)
            return slideshows
            
        } catch {
            print("Error loading slideshows: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Save slideshows to persistent storage
    func saveSlideshows(_ slideshows: [Slideshow]) {
        do {
            let url = try fileURL
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(slideshows)
            try data.write(to: url, options: .atomic)
            
        } catch {
            print("Error saving slideshows: \(error.localizedDescription)")
        }
    }
}
