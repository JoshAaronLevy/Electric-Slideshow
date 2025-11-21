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
    @State private var showingPermissionInstructions = false
    
    init(photoService: PhotoLibraryService) {
        _permissionVM = StateObject(wrappedValue: PermissionViewModel(photoService: photoService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Show notification bar if permission is not granted
            if permissionVM.state == .notDetermined || permissionVM.state == .denied {
                PermissionNotificationBar(
                    state: permissionVM.state,
                    onRequestAccess: {
                        print("🔍 AppShellView: Grant Access button tapped")
                        print("🔍 AppShellView: Current permission state: \(permissionVM.state)")
                        // Use Task to properly handle async call in non-async context
                        Task {
                            print("🔍 AppShellView: Starting permission request")
                            await permissionVM.requestAuthorizationSync()
                            print("🔍 AppShellView: Permission request completed")
                        }
                    },
                    onShowInstructions: {
                        showingPermissionInstructions = true
                    }
                )
            }
            
            // Main content - always show (even if permissions not granted)
            if permissionVM.state == .checking {
                CheckingPermissionView()
            } else {
                AppMainView()
            }
        }
        .sheet(isPresented: $showingPermissionInstructions) {
            PermissionInstructionsSheet(permissionVM: permissionVM)
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

/// Notification bar shown at the top when photo access is not granted
private struct PermissionNotificationBar: View {
    let state: PermissionState
    let onRequestAccess: () -> Void
    let onShowInstructions: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state == .notDetermined ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(state == .notDetermined ? .blue : .orange)
            
            Text(state == .notDetermined ? "Photo access required" : "Photo access denied")
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            if state == .notDetermined {
                Button("Grant Access") {
                    onRequestAccess()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button("View Instructions") {
                    onShowInstructions()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            (state == .notDetermined ? Color.blue : Color.orange)
                .opacity(0.1)
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.secondary.opacity(0.2)),
            alignment: .bottom
        )
    }
}

/// Sheet with instructions for granting photo access
private struct PermissionInstructionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var permissionVM: PermissionViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)
            
            // Content
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
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
                
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Open System Settings", systemImage: "gear")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(minWidth: 500, minHeight: 600)
    }
}

/// Shown when permission is denied or restricted (kept for backward compatibility but no longer used in main flow)
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
            
            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open System Settings", systemImage: "gear")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
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
