internal import SwiftUI

/// Card component for displaying a slideshow in grid layout
struct SlideshowCardView: View {
    let slideshow: Slideshow
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject private var photoService: PhotoLibraryService
    @EnvironmentObject private var playlistsStore: PlaylistsStore
    @State private var thumbnailImage: NSImage?
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail with play button overlay
            ZStack(alignment: .center) {
                thumbnailView
                
                if isHovered {
                    playButtonOverlay
                }
            }
            .aspectRatio(16/9, contentMode: .fill)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            
            // Metadata section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(slideshow.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Context menu button
                    Menu {
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                
                HStack(spacing: 8) {
                    Label("\(slideshow.photoCount)", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                    
                    Text(slideshow.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let playlistId = slideshow.settings.linkedPlaylistId,
                       let playlist = playlistsStore.getPlaylist(byId: playlistId) {
                        Text("•")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                                .font(.caption)
                            Text(playlist.name)
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .task {
            await loadThumbnail()
        }
    }
    
    // MARK: - Thumbnail View
    
    @ViewBuilder
    private var thumbnailView: some View {
        if let image = thumbnailImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color.gray.opacity(0.2)
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }
    
    // MARK: - Play Button Overlay
    
    private var playButtonOverlay: some View {
        Button(action: onPlay) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.6))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "play.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .offset(x: 2) // Optical alignment
            }
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Load Thumbnail
    
    private func loadThumbnail() async {
        guard let firstPhoto = slideshow.photos.first else { return }
        
        let photoAsset = PhotoAsset(localIdentifier: firstPhoto.localIdentifier)
        let size = CGSize(width: 600, height: 400) // Card thumbnail size
        
        thumbnailImage = await photoService.thumbnail(for: photoAsset, size: size)
    }
}
