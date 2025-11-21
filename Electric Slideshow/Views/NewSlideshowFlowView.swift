//
//  NewSlideshowFlowView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

internal import SwiftUI

/// Multi-step flow for creating a new slideshow
struct NewSlideshowFlowView: View {
    @StateObject private var viewModel: NewSlideshowViewModel
    @StateObject private var photoLibraryVM: PhotoLibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var photoService: PhotoLibraryService
    @EnvironmentObject private var playlistsStore: PlaylistsStore
    
    @State private var currentStep: FlowStep = .photoSelection
    @State private var musicSelection: MusicSelection = .none
    
    let onSave: (Slideshow) -> Void
    
    init(photoService: PhotoLibraryService, editingSlideshow: Slideshow? = nil, onSave: @escaping (Slideshow) -> Void) {
        self.onSave = onSave
        self._viewModel = StateObject(wrappedValue: NewSlideshowViewModel(editingSlideshow: editingSlideshow))
        self._photoLibraryVM = StateObject(wrappedValue: PhotoLibraryViewModel(photoService: photoService))
        
        // Initialize music selection from editing slideshow
        if let playlistId = editingSlideshow?.settings.linkedPlaylistId {
            self._musicSelection = State(initialValue: .appPlaylist(playlistId))
        }
    }
    
    enum MusicSelection: Hashable {
        case none
        case appPlaylist(UUID)
    }
    
    private var appPlaylists: [AppPlaylist] {
        playlistsStore.playlists
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .photoSelection:
                    PhotoSelectionView(viewModel: photoLibraryVM)
                        .environmentObject(photoService)
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                case .settings:
                    settingsView
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentStep)
            .navigationTitle(currentStep.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                
                ToolbarItem(placement: .navigation) {
                    if currentStep == .settings {
                        Button {
                            currentStep = .photoSelection
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .keyboardShortcut("[", modifiers: [.command])
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    primaryActionButton
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // MARK: - Settings Step
    
    private var settingsView: some View {
        Form {
            // Summary section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title)
                        .foregroundStyle(.blue)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.selectedPhotoIds.count) Photos Selected")
                            .font(.headline)
                        
                        Text("Ready to customize your slideshow")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        currentStep = .photoSelection
                    } label: {
                        Text("Change Selection")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Slideshow Title", text: $viewModel.title, prompt: Text("My Slideshow"))
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                    
                    if !viewModel.title.isEmpty {
                        if !viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Label("Title looks good", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Label("Title cannot be only whitespace", systemImage: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } header: {
                Text("Basic Information")
            } footer: {
                if viewModel.title.isEmpty {
                    Text("Give your slideshow a memorable name")
                        .font(.caption)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Duration per slide")
                            .font(.body)
                        Spacer()
                        Text("\(viewModel.settings.durationPerSlide, specifier: "%.1f")s")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(
                        value: Binding(
                            get: { viewModel.settings.durationPerSlide },
                            set: { viewModel.settings.durationPerSlide = $0 }
                        ),
                        in: 1...10,
                        step: 0.5
                    )
                }
            } header: {
                Text("Timing")
            } footer: {
                Text("How long each photo will be displayed during the slideshow")
                    .font(.caption)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { viewModel.settings.shuffle },
                        set: { viewModel.settings.shuffle = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Shuffle photos")
                                .font(.body)
                            Text("Photos will be displayed in random order")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    Toggle(isOn: Binding(
                        get: { viewModel.settings.repeatEnabled },
                        set: { viewModel.settings.repeatEnabled = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Repeat slideshow")
                                .font(.body)
                            Text("Slideshow will loop continuously")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Playback Options")
            }
            
            Section {
                Picker("Background Music", selection: $musicSelection) {
                    Text("No Music")
                        .tag(MusicSelection.none)
                    
                    if !appPlaylists.isEmpty {
                        Divider()
                        
                        ForEach(appPlaylists) { playlist in
                            HStack {
                                Image(systemName: "music.note.list")
                                Text(playlist.name)
                            }
                            .tag(MusicSelection.appPlaylist(playlist.id))
                        }
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Music")
            } footer: {
                if case .appPlaylist = musicSelection {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.caption2)
                        Text("Music will play during slideshow")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                } else if appPlaylists.isEmpty {
                    Text("Create playlists in the Music section to add background music")
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Toolbar Actions
    
    @ViewBuilder
    private var primaryActionButton: some View {
        switch currentStep {
        case .photoSelection:
            Button("Next") {
                // Sync selected photo IDs to the slideshow view model
                viewModel.selectedPhotoIds = Array(photoLibraryVM.selectedAssetIds)
                currentStep = .settings
            }
            .disabled(photoLibraryVM.selectedCount == 0)
            .keyboardShortcut(.return, modifiers: .command)
            
        case .settings:
            Button("Save") {
                saveSlideshow()
            }
            .disabled(!viewModel.canSave)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
    
    // MARK: - Actions
    
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
        
        // Reset view model for next time
        viewModel.reset()
        photoLibraryVM.clearSelection()
        musicSelection = .none
        
        dismiss()
    }
}

// MARK: - Flow Step

extension NewSlideshowFlowView {
    enum FlowStep {
        case photoSelection
        case settings
        
        var title: String {
            switch self {
            case .photoSelection:
                return "Select Photos"
            case .settings:
                return "Slideshow Settings"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let photoService = PhotoLibraryService()
    return NewSlideshowFlowView(photoService: photoService) { slideshow in
        print("Saved slideshow: \(slideshow.title)")
    }
    .environmentObject(photoService)
}
