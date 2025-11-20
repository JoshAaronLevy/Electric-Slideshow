//
//  AlbumListView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Sidebar view displaying the list of photo albums
struct AlbumListView: View {
    @Bindable var viewModel: AlbumListViewModel
    @Binding var selectedAlbum: Album?
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading albums...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Request Access") {
                        Task {
                            await viewModel.requestAuthorization()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.albums.isEmpty {
                VStack(spacing: 16) {
                    Text("No albums found")
                        .foregroundColor(.secondary)
                    
                    Button("Reload") {
                        Task {
                            await viewModel.loadAlbums()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.albums, selection: $selectedAlbum) { album in
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(album.title)
                                .font(.body)
                            
                            Text("\(album.assetCount) photos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(album)
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Albums")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    Task {
                        await viewModel.loadAlbums()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            if viewModel.albums.isEmpty {
                await viewModel.requestAuthorization()
            }
        }
    }
}
