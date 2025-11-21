//
//  NewSlideshowViewModel.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation
import Combine

/// Manages temporary state for creating a new slideshow
@MainActor
class NewSlideshowViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var selectedPhotoIds: [String] = []
    @Published var settings: SlideshowSettings = .default
    
    private let editingSlideshow: Slideshow?
    
    init(editingSlideshow: Slideshow? = nil) {
        self.editingSlideshow = editingSlideshow
        
        if let slideshow = editingSlideshow {
            self.title = slideshow.title
            self.selectedPhotoIds = slideshow.photos.map { $0.localIdentifier }
            self.settings = slideshow.settings
        }
    }
    
    /// Whether the slideshow has enough data to be saved
    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedPhotoIds.isEmpty
    }
    
    /// Reset all state to defaults for creating a new slideshow
    func reset() {
        title = ""
        selectedPhotoIds = []
        settings = .default
    }
    
    /// Build a Slideshow from the current state
    /// Returns nil if validation fails
    func buildSlideshow() -> Slideshow? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            return nil
        }
        
        guard !selectedPhotoIds.isEmpty else {
            return nil
        }
        
        let photos = selectedPhotoIds.map { SlideshowPhoto(localIdentifier: $0) }
        
        if let existing = editingSlideshow {
            // Editing existing slideshow
            var updated = existing
            updated.title = trimmedTitle
            updated.photos = photos
            updated.settings = settings
            return updated
        } else {
            // Creating new slideshow
            return Slideshow(
                title: trimmedTitle,
                photos: photos,
                settings: settings
            )
        }
    }
}
