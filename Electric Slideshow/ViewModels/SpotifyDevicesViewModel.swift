import Foundation
import Combine

@MainActor
final class SpotifyDevicesViewModel: ObservableObject {
    @Published var devices: [SpotifyDevice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let apiService: SpotifyAPIService
    
    init(apiService: SpotifyAPIService) {
        self.apiService = apiService
    }
    
    func loadDevices() async {
        isLoading = true
        errorMessage = nil
        do {
            let devices = try await apiService.fetchAvailableDevices()
            self.devices = devices
            if devices.isEmpty {
                errorMessage = nil // Show friendly empty state in view
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
