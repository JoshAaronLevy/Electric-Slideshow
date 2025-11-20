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
            Section {
                TextField("Slideshow Title", text: $viewModel.title, prompt: Text("Enter a title"))
                    .textFieldStyle(.roundedBorder)
                
                if !viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("Title is required", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Title is required", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Basic Information")
            }
            
            Section {
                HStack {
                    Text("Duration per slide")
                    Spacer()
                    Text("\(viewModel.settings.durationPerSlide, specifier: "%.1f") seconds")
                        .foregroundStyle(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { viewModel.settings.durationPerSlide },
                        set: { viewModel.settings.durationPerSlide = $0 }
                    ),
                    in: 1...10,
                    step: 0.5
                )
                
                Text("How long each photo will be displayed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Timing")
            }
            
            Section {
                Toggle("Shuffle photos", isOn: Binding(
                    get: { viewModel.settings.shuffle },
                    set: { viewModel.settings.shuffle = $0 }
                ))
                
                Text("Photos will be displayed in random order")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Toggle("Repeat slideshow", isOn: Binding(
                    get: { viewModel.settings.repeatEnabled },
                    set: { viewModel.settings.repeatEnabled = $0 }
                ))
                
                Text("Slideshow will loop continuously")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
