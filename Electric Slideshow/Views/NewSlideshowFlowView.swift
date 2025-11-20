//
//  NewSlideshowFlowView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Multi-step flow for creating a new slideshow
struct NewSlideshowFlowView: View {
    @StateObject private var viewModel = NewSlideshowViewModel()
    @StateObject private var photoLibraryVM: PhotoLibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var photoService: PhotoLibraryService
    
    @State private var currentStep: FlowStep = .photoSelection
    
    let onSave: (Slideshow) -> Void
    
    init(photoService: PhotoLibraryService, onSave: @escaping (Slideshow) -> Void) {
        self.onSave = onSave
        self._photoLibraryVM = StateObject(wrappedValue: PhotoLibraryViewModel(photoService: photoService))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .photoSelection:
                    PhotoSelectionView(viewModel: photoLibraryVM)
                        .environmentObject(photoService)
                case .settings:
                    settingsView
                }
            }
            .navigationTitle(currentStep.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigation) {
                    if currentStep == .settings {
                        Button {
                            currentStep = .photoSelection
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
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
            
        case .settings:
            Button("Save") {
                saveSlideshow()
            }
            .disabled(!viewModel.canSave)
        }
    }
    
    // MARK: - Actions
    
    private func saveSlideshow() {
        guard let slideshow = viewModel.buildSlideshow() else {
            return
        }
        
        onSave(slideshow)
        
        // Reset view model for next time
        viewModel.reset()
        photoLibraryVM.clearSelection()
        
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
