//
//  InternalPlayerManager.swift
//  Electric Slideshow
//
//  Manages the Electron-based internal player as a child process.
//  Launches the player app with Spotify token injection via environment variables.
//

import Foundation
import Combine

/// Errors that can occur when managing the internal player process
enum InternalPlayerError: Error, LocalizedError {
    case invalidPath(String)
    case processLaunchFailed(String)
    case noAccessToken
    
    var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid internal player path: \(path)"
        case .processLaunchFailed(let reason):
            return "Failed to launch internal player: \(reason)"
        case .noAccessToken:
            return "No Spotify access token available"
        }
    }
}

/// Launch mode for the internal player
enum InternalPlayerLaunchMode {
    /// Development mode: runs from local repo with npm run dev
    case dev
    /// Production mode: runs from bundled .app
    case bundled
}

/// Manages the lifecycle of the Electron internal player process
@MainActor
final class InternalPlayerManager: ObservableObject {
    
    // MARK: - Configuration
    
    /// TODO: Edit this to point to your local electric-slideshow-internal-player repo
    /// Example: "/Users/yourname/Projects/electric-slideshow-internal-player"
    static let defaultDevRepoPath = "/Users/joshlevy/Desktop/electric-slideshow-internal-player"
    
    // MARK: - Published State
    
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastError: String?
    
    // MARK: - Private Properties
    
    private var process: Process?
    private let launchMode: InternalPlayerLaunchMode
    private let devRepoPath: String
    
    // MARK: - Initialization
    
    init(
        launchMode: InternalPlayerLaunchMode = .dev,
        devRepoPath: String = InternalPlayerManager.defaultDevRepoPath
    ) {
        self.launchMode = launchMode
        self.devRepoPath = devRepoPath
    }
    
    // MARK: - Public API
    
    /// Starts the internal player with the provided Spotify access token
    /// - Parameter token: Valid Spotify access token for Web Playback SDK
    /// - Throws: InternalPlayerError if the process cannot be launched
    func start(withAccessToken token: String) throws {
        guard !isRunning else {
            print("[InternalPlayerManager] Internal player already running")
            return
        }
        
        // Log token prefix only for security
        let tokenPrefix = String(token.prefix(8))
        print("[InternalPlayerManager] Using token prefix: \(tokenPrefix)…")
        
        switch launchMode {
        case .dev:
            try startDevMode(token: token)
        case .bundled:
            try startBundledMode(token: token)
        }
    }
    
    /// Stops the internal player process
    func stop() {
        guard let process = process, process.isRunning else {
            print("[InternalPlayerManager] No running process to stop")
            isRunning = false
            return
        }
        
        print("[InternalPlayerManager] Stopping internal player (PID: \(process.processIdentifier))")
        
        process.terminate()
        
        // Wait for termination in background
        Task.detached {
            process.waitUntilExit()
            await MainActor.run {
                self.process = nil
                self.isRunning = false
                print("[InternalPlayerManager] Internal player stopped")
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func startDevMode(token: String) throws {
        let repoURL = URL(fileURLWithPath: devRepoPath)
        
        // Verify the path exists
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: repoURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            let error = InternalPlayerError.invalidPath(devRepoPath)
            lastError = error.localizedDescription
            print("[InternalPlayerManager] ERROR: Invalid path: \(devRepoPath)")
            PlayerInitLogger.shared.log(
                "ERROR: Invalid path: \(devRepoPath)",
                source: "InternalPlayerManager"
            )
            throw error
        }
        
        print("[InternalPlayerManager] Starting internal player in dev mode at \(repoURL.path)")
        PlayerInitLogger.shared.log(
            "Starting internal player in dev mode at \(repoURL.path)",
            source: "InternalPlayerManager"
        )
        
        // Create process
        let newProcess = Process()
        newProcess.currentDirectoryURL = repoURL
        newProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        newProcess.arguments = ["npm", "run", "dev"]
        
        // Set up environment with token
        var environment = ProcessInfo.processInfo.environment
        environment["SPOTIFY_ACCESS_TOKEN"] = token
        environment["ELECTRIC_SLIDESHOW_MODE"] = "internal-player"
        print("[InternalPlayerManager] Setting environment variables: SPOTIFY_ACCESS_TOKEN, ELECTRIC_SLIDESHOW_MODE")
        PlayerInitLogger.shared.log(
            "Setting environment variables: SPOTIFY_ACCESS_TOKEN, ELECTRIC_SLIDESHOW_MODE",
            source: "InternalPlayerManager"
        )
        newProcess.environment = environment
        
        // Set up termination handler
        newProcess.terminationHandler = { [weak self] process in
            Task { @MainActor in
                print("[InternalPlayerManager] Process terminated with status: \(process.terminationStatus)")
                PlayerInitLogger.shared.log(
                    "Process terminated with status: \(process.terminationStatus)",
                    source: "InternalPlayerManager"
                )
                self?.process = nil
                self?.isRunning = false
            }
        }
        
        // Launch
        do {
            try newProcess.run()
            self.process = newProcess
            self.isRunning = true
            print("[InternalPlayerManager] Process launched with PID \(newProcess.processIdentifier)")
            PlayerInitLogger.shared.log(
                "Process launched with PID \(newProcess.processIdentifier)",
                source: "InternalPlayerManager"
            )
            lastError = nil
        } catch {
            let playerError = InternalPlayerError.processLaunchFailed(error.localizedDescription)
            lastError = playerError.localizedDescription
            print("[InternalPlayerManager] ERROR: Process launch failed: \(error.localizedDescription)")
            PlayerInitLogger.shared.log(
                "ERROR: Process launch failed: \(error.localizedDescription)",
                source: "InternalPlayerManager"
            )
            throw playerError
        }
    }
    
    private func startBundledMode(token: String) throws {
        // TODO: Implement bundled mode once we have a packaged .app
        print("[InternalPlayerManager] Bundled mode not yet implemented")
        lastError = "Bundled mode is not yet implemented. Use dev mode for now."
        throw InternalPlayerError.processLaunchFailed("Bundled mode not implemented")
    }
}
