//
//  PhotoGridView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Grid view displaying photos from the selected album
struct PhotoGridView: View {
    @Bindable var viewModel: PhotoGridViewModel
    let album: Album?
    @State private var selectedPhoto: PhotoAsset?
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        Group {
            if let album = album {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView("Loading photos...")
                            .progressViewStyle(.linear)
                        Text("Fetching \(album.assetCount) photos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error {
                    ContentUnavailableView(
                        "Failed to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.errorDescription ?? "An error occurred")
                    )
                } else if viewModel.photos.isEmpty {
                    ContentUnavailableView(
                        "No Photos",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("This album is empty")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.photos) { photo in
                                PhotoThumbnailView(
                                    photo: photo,
                                    thumbnail: viewModel.thumbnail(for: photo)
                                )
                                .onTapGesture {
                                    selectedPhoto = photo
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Show loading progress when thumbnails are loading
                    if viewModel.loadingProgress > 0 && viewModel.loadingProgress < 1.0 {
                        VStack {
                            Spacer()
                            HStack {
                                ProgressView(value: viewModel.loadingProgress) {
                                    Text("Loading thumbnails... \(Int(viewModel.loadingProgress * 100))%")
                                        .font(.caption)
                                }
                                .frame(maxWidth: 300)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                            }
                            .padding(.bottom)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select an Album",
                    systemImage: "photo.stack",
                    description: Text("Choose an album from the sidebar to view photos")
                )
            }
        }
        .navigationTitle(album?.title ?? "Photos")
        .navigationSubtitle(album.map { "\($0.assetCount) photos" } ?? "")
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo, photoService: viewModel)
        }
        .onChange(of: album) { oldValue, newValue in
            if let newAlbum = newValue {
                Task {
                    await viewModel.loadPhotos(from: newAlbum)
                }
            }
        }
    }
}

/// Individual thumbnail cell in the grid
struct PhotoThumbnailView: View {
    let photo: PhotoAsset
    let thumbnail: NSImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 150, height: 150)
                    .clipped()
                    .cornerRadius(8)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 150, height: 150)
                    .cornerRadius(8)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.2), value: thumbnail != nil)
    }
}
