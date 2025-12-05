//
//  InternalPlayerManager.swift
//  Electric Slideshow
//
//  Manages the Electron-based internal player as a child process.
//  Launches the player app with Spotify token injection via environment variables.
//

import Combine
import Foundation

/// Errors that can occur when managing the internal player process
enum InternalPlayerError: Error, LocalizedError {
    case invalidPath(String)
    case processLaunchFailed(String)
    case noAccessToken
    case helperNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid internal player path: \(path)"
        case .processLaunchFailed(let reason):
            return "Failed to launch internal player: \(reason)"
        case .noAccessToken:
            return "No Spotify access token available"
        case .helperNotFound:
            return "Embedded internal player helper not found in app bundle"
        }
    }
}

/// Manages the lifecycle of the Electron internal player process
@MainActor
final class InternalPlayerManager: ObservableObject {
    
    // MARK: - Configuration
    
    /// TODO: Edit this to point to your local electric-slideshow-internal-player repo
    /// Example: "/Users/yourname/Projects/electric-slideshow-internal-player"
    static let defaultDevRepoPath = "/Users/joshlevy/Desktop/electric-slideshow-internal-player"
    
    static let shared = InternalPlayerManager()
    
    // MARK: - Published State
    
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastError: String?
    
    // MARK: - Private Properties
    
    private var process: Process?
    private let devRepoPath: String
    
    // MARK: - Initialization
    
    init(
        devRepoPath: String = InternalPlayerManager.defaultDevRepoPath
    ) {
        self.devRepoPath = devRepoPath
    }
    
    // MARK: - Public API
    
    func ensureInternalPlayerRunning(accessToken: String, backendBaseURL: URL?) throws {
        if let process, process.isRunning {
            isRunning = true
            print("[InternalPlayerManager] Internal player already running (pid \(process.processIdentifier)), reusing existing process")
            PlayerInitLogger.shared.log(
                "Internal player already running (pid \(process.processIdentifier)), reusing existing process",
                source: "InternalPlayerManager"
            )
            return
        }
        
        try startInternalPlayer(accessToken: accessToken, backendBaseURL: backendBaseURL)
    }
    
    /// Starts the internal player with the provided Spotify access token
    /// - Throws: InternalPlayerError if the process cannot be launched
    func startInternalPlayer(accessToken: String, backendBaseURL: URL?) throws {
        guard process?.isRunning != true else {
            isRunning = true
            print("[InternalPlayerManager] Start requested but process already running (pid \(process?.processIdentifier ?? 0))")
            PlayerInitLogger.shared.log(
                "Start requested but process already running (pid \(process?.processIdentifier ?? 0))",
                source: "InternalPlayerManager"
            )
            return
        }
        
        let environment = buildEnvironment(accessToken: accessToken, backendBaseURL: backendBaseURL)
        
        #if DEBUG
        try launchDevProcess(environment: environment)
        #else
        try launchBundledProcess(environment: environment)
        #endif
    }
    
    /// Stops the internal player process
    func stopInternalPlayer() {
        guard let process else {
            print("[InternalPlayerManager] No running process to stop")
            isRunning = false
            return
        }
        
        guard process.isRunning else {
            print("[InternalPlayerManager] Process already stopped")
            self.process = nil
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
                PlayerInitLogger.shared.log(
                    "Internal player stopped",
                    source: "InternalPlayerManager"
                )
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func buildEnvironment(accessToken: String, backendBaseURL: URL?) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["SPOTIFY_ACCESS_TOKEN"] = accessToken
        environment["ELECTRIC_SLIDESHOW_MODE"] = "internal-player"
        if let backendBaseURL {
            environment["ELECTRIC_BACKEND_BASE_URL"] = backendBaseURL.absoluteString
        }
        print("[InternalPlayerManager] Environment set (token prefix \(accessToken.prefix(6))…, backend url set: \(backendBaseURL != nil))")
        PlayerInitLogger.shared.log(
            "Environment set (token prefix \(accessToken.prefix(6))…, backend url set: \(backendBaseURL != nil))",
            source: "InternalPlayerManager"
        )
        return environment
    }
    
    private func attachTerminationHandler(to process: Process) {
        process.terminationHandler = { [weak self] process in
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
    }
    
    #if DEBUG
    private func launchDevProcess(environment: [String: String]) throws {
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
        
        let newProcess = Process()
        newProcess.currentDirectoryURL = repoURL
        newProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        newProcess.arguments = ["npm", "run", "dev"]
        newProcess.environment = environment
        
        attachTerminationHandler(to: newProcess)
        
        do {
            try newProcess.run()
            process = newProcess
            isRunning = true
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
    #else
    private func launchBundledProcess(environment: [String: String]) throws {
        guard let helperURL = Bundle.main
            .url(forResource: "ElectricSlideshowInternalPlayer", withExtension: "app")?
            .appendingPathComponent("Contents/MacOS/ElectricSlideshowInternalPlayer") else {
            let error = InternalPlayerError.helperNotFound
            lastError = error.localizedDescription
            print("[InternalPlayerManager] ERROR: Embedded helper not found in bundle")
            PlayerInitLogger.shared.log(
                "ERROR: Embedded helper not found in bundle",
                source: "InternalPlayerManager"
            )
            throw error
        }
        
        print("[InternalPlayerManager] Starting bundled internal player at \(helperURL.path)")
        PlayerInitLogger.shared.log(
            "Starting bundled internal player at \(helperURL.path)",
            source: "InternalPlayerManager"
        )
        
        let newProcess = Process()
        newProcess.executableURL = helperURL
        newProcess.environment = environment
        
        attachTerminationHandler(to: newProcess)
        
        do {
            try newProcess.run()
            process = newProcess
            isRunning = true
            print("[InternalPlayerManager] Bundled process launched with PID \(newProcess.processIdentifier)")
            PlayerInitLogger.shared.log(
                "Bundled process launched with PID \(newProcess.processIdentifier)",
                source: "InternalPlayerManager"
            )
            lastError = nil
        } catch {
            let playerError = InternalPlayerError.processLaunchFailed(error.localizedDescription)
            lastError = playerError.localizedDescription
            print("[InternalPlayerManager] ERROR: Bundled process launch failed: \(error.localizedDescription)")
            PlayerInitLogger.shared.log(
                "ERROR: Bundled process launch failed: \(error.localizedDescription)",
                source: "InternalPlayerManager"
            )
            throw playerError
        }
    }
    #endif
}
