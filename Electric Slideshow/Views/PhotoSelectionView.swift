//
//  PhotoSelectionView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Photo selection UI with album picker and multi-select grid
struct PhotoSelectionView: View {
    @ObservedObject var viewModel: PhotoLibraryViewModel
    @EnvironmentObject private var photoService: PhotoLibraryService
    
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 8)
    ]
    
    var body: some View {
        HSplitView {
            // Left sidebar: Album list
            albumSidebar
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            
            // Right content: Photo grid
            photoGrid
                .frame(minWidth: 400)
        }
        .task {
            if viewModel.albums.isEmpty {
                await viewModel.loadAlbums()
            }
        }
    }
    
    // MARK: - Album Sidebar
    
    private var albumSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Albums")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider()
            
            if viewModel.isLoadingAlbums {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.albums.isEmpty {
                ContentUnavailableView(
                    "No Albums",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("No photo albums found")
                )
            } else {
                albumList
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var albumList: some View {
        List(viewModel.albums, id: \.id, selection: Binding(
            get: { viewModel.selectedAlbum },
            set: { newAlbum in
                if let album = newAlbum {
                    Task {
                        await viewModel.selectAlbum(album)
                    }
                }
            }
        )) { album in
            AlbumRow(album: album)
                .tag(album)
        }
        .listStyle(.sidebar)
    }
    
    // MARK: - Photo Grid
    
    private var photoGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with selection info
            gridHeader
            
            Divider()
            
            // Grid content
            if viewModel.isLoadingAssets {
                ProgressView("Loading photos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.assets.isEmpty {
                emptyGridState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(viewModel.assets) { asset in
                            PhotoThumbnailView(
                                asset: asset,
                                isSelected: viewModel.isSelected(asset),
                                photoService: photoService
                            )
                            .onTapGesture {
                                viewModel.toggleSelection(for: asset)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
    }
    
    private var gridHeader: some View {
        HStack {
            if let album = viewModel.selectedAlbum {
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title)
                        .font(.headline)
                    
                    Text("\(viewModel.selectedCount) of \(viewModel.assets.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select an album")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !viewModel.assets.isEmpty {
                HStack(spacing: 8) {
                    Button("Select All") {
                        viewModel.selectAll()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.selectedCount == viewModel.assets.count)
                    
                    Button("Clear") {
                        viewModel.clearSelection()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.selectedCount == 0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var emptyGridState: some View {
        ContentUnavailableView(
            "No Photos",
            systemImage: "photo",
            description: Text(viewModel.selectedAlbum != nil ? "This album is empty" : "Select an album to view photos")
        )
    }
}

// MARK: - Album Row

private struct AlbumRow: View {
    let album: Album
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.body)
                
                Text("\(album.assetCount) photo\(album.assetCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Photo Thumbnail View

private struct PhotoThumbnailView: View {
    let asset: PhotoAsset
    let isSelected: Bool
    let photoService: PhotoLibraryService
    
    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    
    private let thumbnailSize = CGSize(width: 300, height: 300)
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail
            Group {
                if let image = thumbnail {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 120, height: 120)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 24, height: 24)
                    )
                    .padding(8)
            }
        }
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        isLoading = true
        thumbnail = await photoService.thumbnail(for: asset, size: thumbnailSize)
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    PhotoSelectionView(
        viewModel: PhotoLibraryViewModel(photoService: PhotoLibraryService())
    )
    .environmentObject(PhotoLibraryService())
    .frame(width: 900, height: 600)
}
