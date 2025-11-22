//
//  PhotoDetailView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI
import Photos

/// Detail view showing a larger version of the selected photo
struct PhotoDetailView: View {
    let photo: PhotoAsset
    @Bindable var photoService: PhotoGridViewModel
    @State private var previewImage: NSImage?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let creationDate = photo.creationDate {
                        Text(creationDate.formatted(date: .long, time: .shortened))
                            .font(.headline)
                    } else {
                        Text("Unknown Date")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(Int(photo.asset.pixelWidth)) × \(Int(photo.asset.pixelHeight))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Image content
            ZStack {
                Color.black
                
                if let previewImage = previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                } else if !isLoading {
                    ContentUnavailableView(
                        "Failed to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Could not load the image")
                    )
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .task {
            await loadImage()
        }
    }
    
    // MARK: - Image Loading
    
    private func loadImage() async {
        // First, show the thumbnail immediately for instant feedback
        if let thumbnail = photoService.thumbnail(for: photo) {
            previewImage = thumbnail
        }
        
        isLoading = true
        
        // Then load a higher quality preview image
        // Note: Using preview size instead of full size for better performance
        // Full size loading can be added later as an enhancement
        if let preview = await photoService.photoService.image(for: photo, size: ImageSize.preview) {
            withAnimation(.easeInOut(duration: 0.3)) {
                previewImage = preview
            }
        }
        
        isLoading = false
    }
}
