import Foundation
import Combine
import SwiftUI

/// Store for managing app-local playlists with JSON file persistence
@MainActor
final class PlaylistsStore: ObservableObject {
    @Published private(set) var playlists: [AppPlaylist] = []
    
    private let fileURL: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documentsPath.appendingPathComponent("app-playlists.json")
        loadPlaylists()
    }
    
    // MARK: - CRUD Operations
    
    func addPlaylist(_ playlist: AppPlaylist) {
        playlists.append(playlist)
        savePlaylists()
    }
    
    func updatePlaylist(_ playlist: AppPlaylist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            var updated = playlist
            updated.updatedAt = Date()
            playlists[index] = updated
            savePlaylists()
        }
    }
    
    func deletePlaylist(_ playlist: AppPlaylist) {
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }
    
    func deletePlaylist(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        savePlaylists()
    }
    
    func getPlaylist(byId id: UUID) -> AppPlaylist? {
        playlists.first { $0.id == id }
    }
    
    // MARK: - Persistence
    
    private func loadPlaylists() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            playlists = try JSONDecoder().decode([AppPlaylist].self, from: data)
        } catch {
            print("Failed to load playlists: \(error)")
        }
    }
    
    private func savePlaylists() {
        do {
            let data = try JSONEncoder().encode(playlists)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to save playlists: \(error)")
        }
    }
}
