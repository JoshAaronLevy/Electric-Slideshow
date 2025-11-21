//
//  ContentView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

internal import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var photoService: PhotoLibraryService
    @State private var albumListViewModel: AlbumListViewModel?
    @State private var photoGridViewModel: PhotoGridViewModel?
    @State private var selectedAlbum: Album?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar: Album List
            if let albumViewModel = albumListViewModel {
                AlbumListView(
                    viewModel: albumViewModel,
                    selectedAlbum: $selectedAlbum
                )
            } else {
                ProgressView("Initializing...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } detail: {
            // Detail: Photo Grid
            if let photoViewModel = photoGridViewModel {
                PhotoGridView(
                    viewModel: photoViewModel,
                    album: selectedAlbum
                )
            } else {
                ContentUnavailableView(
                    "Select an Album",
                    systemImage: "photo.stack",
                    description: Text("Choose an album from the sidebar to view photos")
                )
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            // Initialize view models with the photo service
            if albumListViewModel == nil {
                albumListViewModel = AlbumListViewModel(photoService: photoService)
            }
            if photoGridViewModel == nil {
                photoGridViewModel = PhotoGridViewModel(photoService: photoService)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PhotoLibraryService())
}
