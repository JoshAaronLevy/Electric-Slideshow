//
//  SlideshowsListViewModel.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation
import Combine

/// Manages the list of slideshows and their persistence
@MainActor
class SlideshowsListViewModel: ObservableObject {
    @Published var slideshows: [Slideshow] = []
    
    private let store: SlideshowsStore
    
    /// Whether there are any slideshows
    var isEmpty: Bool {
        slideshows.isEmpty
    }
    
    init(store: SlideshowsStore = SlideshowsStore()) {
        self.store = store
        loadSlideshows()
    }
    
    /// Load slideshows from persistent storage
    func loadSlideshows() {
        slideshows = store.loadSlideshows()
    }
    
    /// Add a new slideshow and persist
    func addSlideshow(_ slideshow: Slideshow) {
        slideshows.append(slideshow)
        saveSlideshows()
    }
    
    /// Delete slideshows at the given offsets
    func deleteSlideshows(at offsets: IndexSet) {
        // Remove in reverse order so indices stay valid
        for index in offsets.sorted(by: >) {
            slideshows.remove(at: index)
        }
        saveSlideshows()
    }
    
    /// Delete a specific slideshow
    func deleteSlideshow(_ slideshow: Slideshow) {
        slideshows.removeAll { $0.id == slideshow.id }
        saveSlideshows()
    }
    
    /// Update an existing slideshow
    func updateSlideshow(_ slideshow: Slideshow) {
        if let index = slideshows.firstIndex(where: { $0.id == slideshow.id }) {
            slideshows[index] = slideshow
            saveSlideshows()
        }
    }
    
    /// Save all slideshows to persistent storage
    private func saveSlideshows() {
        store.saveSlideshows(slideshows)
    }
}
