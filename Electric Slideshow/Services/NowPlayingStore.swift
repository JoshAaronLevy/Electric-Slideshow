//
//  NowPlayingStore.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/26/25.
//

import Foundation
import Combine

/// Global store for tracking the currently playing slideshow
@MainActor
final class NowPlayingStore: ObservableObject {
    /// The slideshow that is currently "now playing" in the app
    @Published var activeSlideshow: Slideshow?
}
