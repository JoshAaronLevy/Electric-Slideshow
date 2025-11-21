//
//  PhotoSelectionView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

internal import SwiftUI

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
                HStack(spacing: 10) {
                    Image(systemName: "photo.stack")
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(album.title)
                            .font(.headline)
                        
                        Text("\(viewModel.selectedCount) of \(viewModel.assets.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundStyle(.secondary)
                    Text("Select an album")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if !viewModel.assets.isEmpty {
                HStack(spacing: 8) {
                    Button("Select All") {
                        viewModel.selectAll()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.selectedCount == viewModel.assets.count)
                    .keyboardShortcut("a", modifiers: .command)
                    
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
        VStack(spacing: 20) {
            Image(systemName: viewModel.selectedAlbum != nil ? "photo.badge.exclamationmark" : "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(viewModel.selectedAlbum != nil ? .orange : .blue)
                .symbolEffect(.pulse.byLayer, options: .repeating)
            
            VStack(spacing: 8) {
                Text(viewModel.selectedAlbum != nil ? "No Photos" : "Select an Album")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(viewModel.selectedAlbum != nil ? "This album doesn't contain any photos" : "Choose an album from the sidebar to browse your photos")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Album Row

private struct AlbumRow: View {
    let album: Album
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "photo.on.rectangle")
                    .font(.body)
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(album.title)
                    .font(.body)
                    .lineLimit(1)
                
                Text("\(album.assetCount) photo\(album.assetCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Photo Thumbnail View

private struct PhotoThumbnailView: View {
    let asset: PhotoAsset
    let isSelected: Bool
    let photoService: PhotoLibraryService
    
    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    @State private var isHovered = false
    
    private let thumbnailSize = CGSize(width: 240, height: 240)
    
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
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 120, height: 120)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.accentColor : (isHovered ? Color.secondary.opacity(0.3) : Color.clear),
                        lineWidth: isSelected ? 3 : 1
                    )
            )
            .shadow(color: .black.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 4 : 2, y: 1)
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 28, height: 28)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .padding(6)
            }
            
            // Hover overlay
            if isHovered && !isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
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
