import SwiftUI

/// View for displaying Spotify connection status and authentication controls
struct MusicView: View {
    @StateObject private var viewModel = MusicViewModel()
    @EnvironmentObject private var spotifyAuthService: SpotifyAuthService
    
    var body: some View {
        VStack(spacing: 16) {
            // Connection Status
            HStack {
                Image(systemName: viewModel.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(viewModel.isConnected ? .green : .red)
                    .font(.title2)
                
                Text(viewModel.statusMessage)
                    .font(.headline)
                
                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Error Message
            if let error = spotifyAuthService.authError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Connect/Disconnect Button
            Button(action: {
                if viewModel.isConnected {
                    viewModel.disconnectFromSpotify()
                } else {
                    viewModel.connectToSpotify()
                }
            }) {
                HStack {
                    if viewModel.isConnecting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: viewModel.isConnected ? "arrow.right.square" : "music.note")
                    }
                    
                    Text(viewModel.isConnected ? "Disconnect from Spotify" : "Connect to Spotify")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isConnected ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(viewModel.isConnecting)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Music")
    }
}

#Preview {
    NavigationStack {
        MusicView()
            .environmentObject(SpotifyAuthService.shared)
    }
}
