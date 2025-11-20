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
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.stack.fill")
                .font(.title2)
                .foregroundStyle(.blue.gradient)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(slideshow.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 12) {
                    Label("\(slideshow.photoCount)", systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text(slideshow.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if isHovered {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
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
