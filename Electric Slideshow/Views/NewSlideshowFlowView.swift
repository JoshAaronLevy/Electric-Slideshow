//
//  NewSlideshowFlowView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

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

                            // Spotify Devices Button
                            Section {
                                Button {
                                    showingDevicesSheet = true
                                } label: {
                                    Label("View Spotify Devices", systemImage: "desktopcomputer")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            ...existing code...
                        }
                        .formStyle(.grouped)
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .sheet(isPresented: $showingDevicesSheet) {
                            SpotifyDevicesSheet()
                        }
                    // MARK: - Spotify Devices Sheet

                    private struct SpotifyDevicesSheet: View {
                        @EnvironmentObject private var playlistsStore: PlaylistsStore
                        @StateObject private var apiService = SpotifyAPIService(authService: SpotifyAuthService.shared)
                        @State private var devices: [SpotifyDevice] = []
                        @State private var isLoading = true
                        @State private var error: String?

                        var body: some View {
                            NavigationStack {
                                Group {
                                    if isLoading {
                                        ProgressView("Loading Spotify devices...")
                                            .padding()
                                    } else if let error = error {
                                        VStack(spacing: 16) {
                                            Image(systemName: "exclamationmark.triangle")
                                                .font(.largeTitle)
                                                .foregroundStyle(.orange)
                                            Text(error)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                    } else if devices.isEmpty {
                                        ContentUnavailableView {
                                            Label("No Devices Found", systemImage: "desktopcomputer")
                                        } description: {
                                            Text("No available Spotify playback devices were found. Make sure Spotify is open on your computer or another device.")
                                        }
                                    } else {
                                        List(devices) { device in
                                            HStack(spacing: 12) {
                                                Image(systemName: device.is_active ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(device.is_active ? .green : .secondary)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(device.name)
                                                        .font(.headline)
                                                    Text(device.type)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                if device.is_active {
                                                    Text("Active")
                                                        .font(.caption2)
                                                        .foregroundStyle(.green)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                                .navigationTitle("Spotify Devices")
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Close") {
                                            // Dismiss sheet
                                            if let window = NSApplication.shared.keyWindow {
                                                window.endSheet(window)
                                            }
                                        }
                                    }
                                }
                            }
                            .onAppear {
                                Task {
                                    do {
                                        isLoading = true
                                        devices = try await apiService.fetchAvailableDevices()
                                        isLoading = false
                                    } catch {
                                        self.error = error.localizedDescription
                                        isLoading = false
                                    }
                                }
                            }
                        }
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
