//
//  AppShellView.swift
//  Electric Slideshow
//
//  Created by Josh Levy on 11/20/25.
//

import SwiftUI

/// Root view that manages the permission flow and navigation
struct AppShellView: View {
    @StateObject private var permissionVM: PermissionViewModel
    
    init(photoService: PhotoLibraryService) {
        _permissionVM = StateObject(wrappedValue: PermissionViewModel(photoService: photoService))
    }
    
    var body: some View {
        Group {
            switch permissionVM.state {
            case .checking:
                CheckingPermissionView()
            case .notDetermined:
                RequestPermissionView(permissionVM: permissionVM)
            case .denied:
                PermissionDeniedView()
            case .granted:
                SlideshowsListView()
            }
        }
        .onAppear {
            permissionVM.checkAuthorizationStatus()
        }
    }
}

// MARK: - Permission States

/// Shown while checking permission status
private struct CheckingPermissionView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Checking Photos permission…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown when permission is not yet determined
private struct RequestPermissionView: View {
    @ObservedObject var permissionVM: PermissionViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 72))
                .foregroundStyle(.blue.gradient)
                .symbolEffect(.bounce, options: .speed(0.5))
            
            VStack(spacing: 12) {
                Text("Photos Access Required")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Electric Slideshow needs access to your Photos library to create and display slideshows.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            Button {
                Task {
                    await permissionVM.requestAuthorization()
                }
            } label: {
                Label("Grant Access", systemImage: "lock.open")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown when permission is denied or restricted
private struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange.gradient)
                .symbolEffect(.pulse.byLayer)
            
            VStack(spacing: 12) {
                Text("Photos Access Denied")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Electric Slideshow requires Photos access to work. Please grant access in System Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("To enable access:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text("1")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.blue))
                        Text("Open System Settings")
                    }
                    
                    HStack(spacing: 10) {
                        Text("2")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.blue))
                        Text("Go to Privacy & Security → Photos")
                    }
                    
                    HStack(spacing: 10) {
                        Text("3")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.blue))
                        Text("Enable access for Electric Slideshow")
                    }
                }
                .font(.body)
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Checking") {
    AppShellView(photoService: PhotoLibraryService())
}

#Preview("Granted") {
    let service = PhotoLibraryService()
    AppShellView(photoService: service)
}
