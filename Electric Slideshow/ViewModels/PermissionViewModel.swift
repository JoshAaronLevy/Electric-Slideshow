//
//  PermissionViewModel.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation
import Photos
import Combine

/// Simplified permission state for UI consumption
enum PermissionState {
    case checking
    case notDetermined
    case granted
    case denied
}

/// Manages Photos library authorization state
@MainActor
class PermissionViewModel: ObservableObject {
    @Published var state: PermissionState = .checking
    
    private let photoService: PhotoLibraryService
    
    init(photoService: PhotoLibraryService) {
        self.photoService = photoService
        
        // Debug logging for troubleshooting
        print("📦 Bundle ID:", Bundle.main.bundleIdentifier ?? "nil")
        print("📸 Initial Photos auth status:", PHPhotoLibrary.authorizationStatus(for: .readWrite).rawValue)
    }
    
    /// Check current authorization status on startup
    func checkAuthorizationStatus() {
        let status = photoService.currentAuthorizationStatus()
        updateState(from: status)
    }
    
    /// Request Photos library authorization (async version)
    func requestAuthorization() async {
        print("🔍 PermissionViewModel: requestAuthorization() called")
        print("🔍 PermissionViewModel: Current state before request: \(state)")
        
        let granted = await photoService.requestAuthorization()
        print("🔍 PermissionViewModel: photoService.requestAuthorization() returned: \(granted)")
        
        let status = photoService.currentAuthorizationStatus()
        print("🔍 PermissionViewModel: Current authorization status after request: \(status.rawValue)")
        
        updateState(from: status)
        print("🔍 PermissionViewModel: Final state after update: \(state)")
    }
    
    /// Convert PHAuthorizationStatus to UI-friendly PermissionState
    private func updateState(from status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined:
            state = .notDetermined
        case .authorized, .limited:
            state = .granted
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .denied
        }
    }
}
