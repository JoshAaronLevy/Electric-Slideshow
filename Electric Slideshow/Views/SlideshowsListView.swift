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
    @EnvironmentObject private var spotifyAuthService: SpotifyAuthService
    @EnvironmentObject private var playlistsStore: PlaylistsStore

    /// Callback into the app shell to start playback & navigate to Now Playing
    let onStartPlayback: (Slideshow) -> Void

    @State private var showingNewSlideshowFlow = false
    @State private var slideshowToEdit: Slideshow?
    @State private var slideshowToDelete: Slideshow?
    
    // 4-column grid layout
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
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
            .tint(Color.appBlue)
        }
    }
    
    // MARK: - Floating Action Button
    
    private var floatingActionButton: some View {
        Button {
            showingNewSlideshowFlow = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.appBlue)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: .command)
        .padding(24)
    }
    
    // MARK: - Grid View
    
    private var slideshowsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.slideshows) { slideshow in
                    SlideshowCardView(
                        slideshow: slideshow,
                        onPlay: {
                            onStartPlayback(slideshow)
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
            .padding(24)
            .overlay(alignment: .bottomTrailing) {
                floatingActionButton
            }
        }
    }
}

#Preview {
    SlideshowsListView { _ in }
        .environmentObject(PhotoLibraryService())
        .environmentObject(SpotifyAuthService.shared)
        .environmentObject(PlaylistsStore())
}
