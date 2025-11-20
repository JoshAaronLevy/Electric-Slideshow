//
//  PhotoDetailView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Detail view showing a larger version of the selected photo
struct PhotoDetailView: View {
    let photo: PhotoAsset
    @Bindable var viewModel: PhotoGridViewModel
    @State private var fullImage: NSImage?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(photo.creationDate?.formatted(date: .long, time: .shortened) ?? "Unknown Date")
                    .font(.headline)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            // Image content
            GeometryReader { geometry in
                if isLoading {
                    ProgressView("Loading image...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let fullImage = fullImage {
                    Image(nsImage: fullImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "Failed to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Could not load the full-size image")
                    )
                }
            }
            .background(Color.black)
        }
        .frame(minWidth: 600, minHeight: 400)
        .task {
            // Load full-size image
            // For now, using the thumbnail as a placeholder
            fullImage = viewModel.thumbnail(for: photo)
            isLoading = false
            
            // TODO: Load actual full-size image in the background
            // This is a placeholder for the MVP
        }
    }
}
