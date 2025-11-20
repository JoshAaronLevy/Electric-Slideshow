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
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isEmpty {
                    emptyStateView
                } else {
                    slideshowsList
                }
            }
            .navigationTitle("Slideshows")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // TODO: Will be wired in Stage 3
                        print("New Slideshow tapped")
                    } label: {
                        Label("New Slideshow", systemImage: "plus")
                    }
                }
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
                // TODO: Will be wired in Stage 3
                print("Create First Slideshow tapped")
            } label: {
                Text("Create Slideshow")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - List View
    
    private var slideshowsList: some View {
        List {
            ForEach(viewModel.slideshows) { slideshow in
                SlideshowRow(slideshow: slideshow)
            }
            .onDelete { indexSet in
                viewModel.deleteSlideshows(at: indexSet)
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Slideshow Row

private struct SlideshowRow: View {
    let slideshow: Slideshow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(slideshow.title)
                .font(.headline)
            
            HStack(spacing: 16) {
                Label("\(slideshow.photoCount) photo\(slideshow.photoCount == 1 ? "" : "s")", 
                      systemImage: "photo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(slideshow.createdAt, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Empty") {
    SlideshowsListView()
}

#Preview("With Slideshows") {
    let view = SlideshowsListView()
    view.viewModel.slideshows = [
        Slideshow(
            title: "Summer Vacation",
            photos: [
                SlideshowPhoto(localIdentifier: "1"),
                SlideshowPhoto(localIdentifier: "2"),
                SlideshowPhoto(localIdentifier: "3")
            ],
            createdAt: Date().addingTimeInterval(-86400 * 7)
        ),
        Slideshow(
            title: "Family Photos",
            photos: [
                SlideshowPhoto(localIdentifier: "4"),
                SlideshowPhoto(localIdentifier: "5")
            ],
            createdAt: Date().addingTimeInterval(-86400 * 2)
        )
    ]
    return view
}
