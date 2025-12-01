import SwiftUI

/// Placeholder detail view for a playlist. Stage 1: shows name and track count; editing to come later.
struct PlaylistDetailView: View {
    let playlistId: UUID
    
    @EnvironmentObject private var playlistsStore: PlaylistsStore
    
    private var playlist: AppPlaylist? {
        playlistsStore.getPlaylist(byId: playlistId)
    }
    
    var body: some View {
        Group {
            if let playlist {
                VStack(alignment: .leading, spacing: 12) {
                    Text(playlist.name)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    
                    Label("\(playlist.trackCount) songs", systemImage: "music.note.list")
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationTitle(playlist.name)
            } else {
                ContentUnavailableView {
                    Label("Playlist not found", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("This playlist could not be loaded.")
                }
            }
        }
    }
}

#Preview {
    let store = PlaylistsStore()
    let sample = AppPlaylist(name: "Sample Playlist", trackURIs: ["spotify:track:123"])
    store.addPlaylist(sample)
    
    return NavigationStack {
        PlaylistDetailView(playlistId: sample.id)
            .environmentObject(store)
    }
}
