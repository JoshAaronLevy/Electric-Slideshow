//
//  SlideshowsListView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Main landing page listing slideshows (Stage 1 placeholder)
struct SlideshowsListView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("No slideshows yet")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Slideshows")
        }
    }
}

#Preview {
    SlideshowsListView()
}
