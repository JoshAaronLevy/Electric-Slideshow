//
//  SlideshowsListViewModel.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation

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
        slideshows.remove(atOffsets: offsets)
        saveSlideshows()
    }
    
    /// Delete a specific slideshow
    func deleteSlideshow(_ slideshow: Slideshow) {
        slideshows.removeAll { $0.id == slideshow.id }
        saveSlideshows()
    }
    
    /// Save all slideshows to persistent storage
    private func saveSlideshows() {
        store.saveSlideshows(slideshows)
    }
}
