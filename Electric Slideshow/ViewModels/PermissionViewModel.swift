//
//  PermissionViewModel.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import Foundation
import Photos

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
    }
    
    /// Check current authorization status on startup
    func checkAuthorizationStatus() {
        let status = photoService.currentAuthorizationStatus()
        updateState(from: status)
    }
    
    /// Request Photos library authorization
    func requestAuthorization() async {
        let granted = await photoService.requestAuthorization()
        let status = photoService.currentAuthorizationStatus()
        updateState(from: status)
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
