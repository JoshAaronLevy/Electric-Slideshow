import SwiftUI

/// Flow view for creating a new app playlist with song selection
struct NewPlaylistFlowView: View {
    @StateObject private var viewModel: NewPlaylistViewModel
    @StateObject private var musicLibraryVM: MusicLibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: FlowStep = .trackSelection
    
    let onSave: (AppPlaylist) -> Void
    
    init(
        spotifyAPIService: SpotifyAPIService,
        playlistsStore: PlaylistsStore,
        onSave: @escaping (AppPlaylist) -> Void
    ) {
        self.onSave = onSave
        self._viewModel = StateObject(wrappedValue: NewPlaylistViewModel(playlistsStore: playlistsStore))
        self._musicLibraryVM = StateObject(wrappedValue: MusicLibraryViewModel(apiService: spotifyAPIService))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .trackSelection:
                    TrackSelectionView(viewModel: musicLibraryVM)
                case .settings:
                    playlistSettingsView
                }
            }
            .navigationTitle(currentStep.title)
            .task {
                await musicLibraryVM.loadLibrary()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                    .pointingHandCursor()
                }
                
                ToolbarItem(placement: .navigation) {
                    if currentStep == .settings {
                        Button {
                            currentStep = .trackSelection
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .pointingHandCursor()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    primaryActionButton
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    private var playlistSettingsView: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.title)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.selectedTrackURIs.count) Songs Selected")
                            .font(.headline)
                        Text("Ready to create your playlist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Change Selection") {
                        currentStep = .trackSelection
                    }
                    .buttonStyle(.bordered)
                    .pointingHandCursor()
                }
            }
            
            Section("Playlist Name") {
                TextField("My Playlist", text: $viewModel.name)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    @ViewBuilder
    private var primaryActionButton: some View {
        switch currentStep {
        case .trackSelection:
            Button("Next") {
                viewModel.selectedTrackURIs = musicLibraryVM.selectedTrackURIs
                currentStep = .settings
            }
            .disabled(musicLibraryVM.selectedTrackURIs.isEmpty)
            .pointingHandCursor()
            
        case .settings:
            Button("Save") {
                savePlaylist()
            }
            .disabled(!viewModel.canSave)
            .pointingHandCursor()
        }
    }
    
    private func savePlaylist() {
        guard let playlist = viewModel.buildPlaylist() else { return }
        onSave(playlist)
        viewModel.reset()
        musicLibraryVM.clearSelection()
        dismiss()
    }
    
    enum FlowStep {
        case trackSelection
        case settings
        
        var title: String {
            switch self {
            case .trackSelection: return "Select Songs"
            case .settings: return "Playlist Settings"
            }
        }
    }
}
