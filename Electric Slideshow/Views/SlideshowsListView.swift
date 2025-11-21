//
//  SlideshowsListView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Main landing page listing slideshows
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

#Preview {
    SlideshowsListView()
}
