//
//  InternalSpotifyPlayer.swift
//  Electric Slideshow
//
//  Skeleton for an internal Spotify player running in a WKWebView.
//  This does NOT yet load the real Spotify Web Playback SDK – it just
//  sets up a webview and a basic JS ↔ Swift message channel so we can
//  plug the SDK in later.
//

import Foundation
import WebKit

/// Simple event coming back from the internal player JS side.
/// We'll expand this later once we wire the real Web Playback SDK.
struct InternalPlayerEvent: Decodable {
    enum EventType: String, Decodable {
        case ready
        case stateChanged
        case error
    }

    let type: EventType
    let message: String?
}

/// A small wrapper around WKWebView that will eventually host the
/// Spotify Web Playback SDK and forward events back to Swift.
final class InternalSpotifyPlayer: NSObject, WKScriptMessageHandler {

    // MARK: - Public callbacks

    /// Called when the JS side sends an event (ready, error, etc.)
    var onEvent: ((InternalPlayerEvent) -> Void)?

    // MARK: - Private properties

    private let webView: WKWebView

    // MARK: - Init

    override init() {
        // Step 1: Create config + content controller WITHOUT referencing self
        let contentController = WKUserContentController()
        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        self.webView = WKWebView(frame: .zero, configuration: config)

        // Step 2: Initialize NSObject
        super.init()

        // Step 3: Now it is safe to reference self
        contentController.add(self, name: "playerEvent")
    }

    // MARK: - Public API

    /// Load the internal player HTML. For now we just load a trivial
    /// inline HTML string that can call back into Swift.
    ///
    /// Later, this will:
    ///  - load a bundled "internal_player.html"
    ///  - initialize the Spotify Web Playback SDK
    ///  - send rich events via the "playerEvent" message channel.
    func load() {
        let html = """
        <!doctype html>
        <html>
        <head><meta charset="UTF-8"><title>Internal Player</title></head>
        <body>
            <script>
            // Minimal JS bridge. Later we'll replace this with the
            // actual Spotify Web Playback SDK integration.

            function notifyReady() {
                try {
                    window.webkit.messageHandlers.playerEvent.postMessage({
                        type: "ready",
                        message: "Internal player skeleton loaded"
                    });
                } catch (e) {
                    console.error("Failed to post ready event", e);
                }
            }

            // Auto-notify Swift that the skeleton has loaded.
            window.onload = notifyReady;
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }

    /// Evaluate arbitrary JS in the web view. We'll use this later
    /// to call functions like playerPlayTrack(), playerPause(), etc.
    func evaluateJavaScript(_ script: String) {
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("[InternalSpotifyPlayer] JS error: \(error)")
            } else if let result = result {
                print("[InternalSpotifyPlayer] JS result: \(result)")
            }
        }
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "playerEvent" else { return }

        if let dict = message.body as? [String: Any] {
            // Try to decode into InternalPlayerEvent using JSON.
            do {
                let data = try JSONSerialization.data(withJSONObject: dict, options: [])
                let event = try JSONDecoder().decode(InternalPlayerEvent.self, from: data)
                onEvent?(event)
            } catch {
                print("[InternalSpotifyPlayer] Failed to decode event: \(error)")
            }
        } else {
            print("[InternalSpotifyPlayer] Unexpected message body: \(message.body)")
        }
    }
}
