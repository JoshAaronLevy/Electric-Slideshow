# Phase 3: Grid Layout, Edit/Delete, and Music Integration

**Prerequisites**: Phase 1 (Spotify Auth) and Phase 2 (App Playlists) must be complete.

**Goal**: Transform the slideshow list into a card-based grid, add edit/delete capabilities, and integrate music selection into slideshow settings.

---

## Stage 1: Convert Slideshow List to Card Grid

### Update `SlideshowsListView.swift`

```swift
import SwiftUI

struct SlideshowsListView: View {
    @StateObject private var viewModel = SlideshowsListViewModel()
    @EnvironmentObject private var photoService: PhotoLibraryService
    @State private var showingNewSlideshowFlow = false
    @State private var slideshowToEdit: Slideshow?
    @State private var slideshowToDelete: Slideshow?
    
    // 3-column grid layout
    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isEmpty {
                    emptyStateView
                } else {
                    slideshowsGrid
                }
            }
            .navigationTitle("Slideshows")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewSlideshowFlow = true
                    } label: {
                        Label("New Slideshow", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
            .sheet(isPresented: $showingNewSlideshowFlow) {
                NewSlideshowFlowView(photoService: photoService) { slideshow in
                    viewModel.addSlideshow(slideshow)
                }
                .environmentObject(photoService)
            }
            .sheet(item: $slideshowToEdit) { slideshow in
                NewSlideshowFlowView(
                    photoService: photoService,
                    editingSlideshow: slideshow
                ) { updatedSlideshow in
                    viewModel.updateSlideshow(updatedSlideshow)
                }
                .environmentObject(photoService)
            }
            .alert("Delete Slideshow?", isPresented: .constant(slideshowToDelete != nil), presenting: slideshowToDelete) { slideshow in
                Button("Cancel", role: .cancel) {
                    slideshowToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    viewModel.deleteSlideshow(slideshow)
                    slideshowToDelete = nil
                }
            } message: { slideshow in
                Text("Are you sure you want to delete \"\(slideshow.title)\"? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Slideshows", systemImage: "photo.stack")
        } description: {
            Text("Create your first slideshow to get started")
        } actions: {
            Button {
                showingNewSlideshowFlow = true
            } label: {
                Text("Create Slideshow")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Grid View
    
    private var slideshowsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(viewModel.slideshows) { slideshow in
                    SlideshowCardView(
                        slideshow: slideshow,
                        onPlay: {
                            // Will implement in Phase 4
                        },
                        onEdit: {
                            slideshowToEdit = slideshow
                        },
                        onDelete: {
                            slideshowToDelete = slideshow
                        }
                    )
                }
            }
            .padding()
        }
    }
}
```

---

## Stage 2: Slideshow Card Component

### Create `Views/SlideshowCardView.swift`

```swift
import SwiftUI

struct SlideshowCardView: View {
    let slideshow: Slideshow
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject private var photoService: PhotoLibraryService
    @State private var thumbnailImage: NSImage?
    @State private var isHovered = false
    @State private var showingContextMenu = false
    
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
                    
                    if slideshow.settings.linkedPlaylistId != nil {
                        Text("•")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                        
                        Image(systemName: "music.note")
                            .font(.caption)
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
```

---

## Stage 3: Update Slideshow Model for Music

### Extend `Models/SlideshowSettings.swift`

```swift
import Foundation

struct SlideshowSettings: Codable, Equatable {
    var durationPerSlide: TimeInterval
    var shuffle: Bool
    var repeatEnabled: Bool
    
    // NEW: Music integration
    var linkedPlaylistId: UUID?  // References AppPlaylist.id
    
    static let `default` = SlideshowSettings(
        durationPerSlide: 3.0,
        shuffle: false,
        repeatEnabled: true,
        linkedPlaylistId: nil
    )
}
```

---

## Stage 4: Add Music Selection to Slideshow Settings

### Update `NewSlideshowFlowView.swift` settings section

Add this to the `settingsView`:

```swift
// Add after "Playback Options" section

Section {
    Picker("Background Music", selection: $musicSelection) {
        Text("No Music")
            .tag(MusicSelection.none)
        
        Divider()
        
        if !appPlaylists.isEmpty {
            ForEach(appPlaylists) { playlist in
                Text(playlist.name)
                    .tag(MusicSelection.appPlaylist(playlist.id))
            }
        }
        
        // Future: Add Spotify playlists section
    }
    .pickerStyle(.menu)
} header: {
    Text("Music")
} footer: {
    if musicSelection != .none {
        HStack(spacing: 4) {
            Image(systemName: "music.note")
                .font(.caption2)
            Text("Music will play during slideshow")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}
```

Add these properties to `NewSlideshowFlowView`:

```swift
@EnvironmentObject private var playlistsStore: PlaylistsStore
@State private var musicSelection: MusicSelection = .none

enum MusicSelection: Hashable {
    case none
    case appPlaylist(UUID)
}

private var appPlaylists: [AppPlaylist] {
    playlistsStore.playlists
}
```

Update the `saveSlideshow()` method to include music:

```swift
private func saveSlideshow() {
    // Update settings with music selection
    switch musicSelection {
    case .none:
        viewModel.settings.linkedPlaylistId = nil
    case .appPlaylist(let id):
        viewModel.settings.linkedPlaylistId = id
    }
    
    guard let slideshow = viewModel.buildSlideshow() else {
        return
    }
    
    onSave(slideshow)
    viewModel.reset()
    photoLibraryVM.clearSelection()
    dismiss()
}
```

---

## Stage 5: Update ViewModel for Editing

### Update `NewSlideshowViewModel.swift`

Add initializer for editing:

```swift
@MainActor
final class NewSlideshowViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var selectedPhotoIds: [String] = []
    @Published var settings: SlideshowSettings = .default
    @Published var errorMessage: String?
    
    private let editingSlideshow: Slideshow?
    
    init(editingSlideshow: Slideshow? = nil) {
        self.editingSlideshow = editingSlideshow
        
        if let slideshow = editingSlideshow {
            self.title = slideshow.title
            self.selectedPhotoIds = slideshow.photos.map { $0.localIdentifier }
            self.settings = slideshow.settings
        }
    }
    
    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedPhotoIds.isEmpty
    }
    
    func buildSlideshow() -> Slideshow? {
        guard canSave else { return nil }
        
        let photos = selectedPhotoIds.map { SlideshowPhoto(localIdentifier: $0) }
        
        if let existing = editingSlideshow {
            // Editing existing slideshow
            var updated = existing
            updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.photos = photos
            updated.settings = settings
            return updated
        } else {
            // Creating new slideshow
            return Slideshow(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                photos: photos,
                settings: settings
            )
        }
    }
    
    func reset() {
        title = ""
        selectedPhotoIds = []
        settings = .default
        errorMessage = nil
    }
}
```

---

## Stage 6: Update SlideshowsListViewModel

### Update `ViewModels/SlideshowsListViewModel.swift`

Add update method:

```swift
@MainActor
final class SlideshowsListViewModel: ObservableObject {
    @Published private(set) var slideshows: [Slideshow] = []
    
    private let store = SlideshowsStore()
    
    init() {
        loadSlideshows()
    }
    
    var isEmpty: Bool {
        slideshows.isEmpty
    }
    
    func addSlideshow(_ slideshow: Slideshow) {
        slideshows.append(slideshow)
        store.save(slideshows: slideshows)
    }
    
    func updateSlideshow(_ slideshow: Slideshow) {
        if let index = slideshows.firstIndex(where: { $0.id == slideshow.id }) {
            slideshows[index] = slideshow
            store.save(slideshows: slideshows)
        }
    }
    
    func deleteSlideshow(_ slideshow: Slideshow) {
        slideshows.removeAll { $0.id == slideshow.id }
        store.save(slideshows: slideshows)
    }
    
    func deleteSlideshows(at offsets: IndexSet) {
        slideshows.remove(atOffsets: offsets)
        store.save(slideshows: slideshows)
    }
    
    private func loadSlideshows() {
        slideshows = store.load()
    }
}
```

---

## Stage 7: Update App to Inject PlaylistsStore

### Update `Electric_SlideshowApp.swift`

```swift
@main
struct Electric_SlideshowApp: App {
    @StateObject private var photoService = PhotoLibraryService()
    @StateObject private var spotifyAuthService = SpotifyAuthService()
    @StateObject private var playlistsStore = PlaylistsStore()
    
    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(photoService)
                .environmentObject(spotifyAuthService)
                .environmentObject(playlistsStore)
                .onOpenURL { url in
                    Task {
                        if url.scheme == "com.electricslideshow" {
                            try? await spotifyAuthService.handleCallback(url: url)
                        }
                    }
                }
        }
    }
}
```

---

## Testing Checklist

1. ✓ Slideshows display in 3-column grid
2. ✓ Cards show thumbnail, title, metadata, music icon
3. ✓ Play button appears on hover over thumbnail
4. ✓ Context menu (⋮) shows edit and delete options
5. ✓ Edit opens slideshow in `NewSlideshowFlowView` with pre-filled data
6. ✓ Delete shows confirmation dialog
7. ✓ Music picker shows app playlists in slideshow settings
8. ✓ Selected music persists with slideshow
9. ✓ Music icon appears on card when playlist is linked
10. ✓ Grid layout looks good in light and dark mode

---

## Next Steps

Proceed to **Phase 4: Slideshow Playback** which includes:
- Full-screen slideshow view
- Auto-advancing slides with fade transitions
- Spotify music playback integration
- Auto-hiding controls with song info
