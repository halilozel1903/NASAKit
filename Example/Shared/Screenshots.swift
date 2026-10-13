import Foundation
import SwiftUI
import NASAKit

/// Scenes used by CI to capture the README screenshots.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
///
/// Every scene shows live data and real images. Nothing is bundled, drawn or faked: when the data
/// or any image on screen fails to load (after four attempts), the scene never reports itself
/// ready and scripts/screenshots.sh fails the CI run instead of committing a capture.
///
/// The scenes use the keyless APIs (the NASA Image and Video Library and EPIC at
/// epic.gsfc.nasa.gov), because `DEMO_KEY` is limited per IP address and CI runners share
/// addresses. The `apod` scene needs a personal key in the `NASA_API_KEY` environment variable;
/// scripts/screenshots.sh skips it when there is none.
enum ScreenshotScene: String {
    /// Apple TV: a hero and rails of NASA Image and Video Library results.
    case home
    /// Apple TV and iPhone: the latest EPIC images of Earth.
    case earth
    /// Apple TV and iPhone: recent Astronomy Pictures of the Day. Needs `NASA_API_KEY`.
    case apod
    /// iPhone: library search results.
    case search
    /// iPhone: the first search result's page.
    case detail

    static var current: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }

    /// The query of the `search` and `detail` scenes.
    static let searchQuery = "apollo 11"

    /// Whether the scene needs a personal api.nasa.gov key.
    var needsAPIKey: Bool {
        self == .apod
    }

    /// The image loader of the screenshot scenes: the network, tried up to four times, and
    /// counted so the scene is only reported ready once every image on screen has loaded.
    static let imageLoader = RemoteImageLoader { url in
        await ScreenshotImageTracker.shared.begin()
        var lastError: any Error = URLError(.unknown)
        for attempt in 0..<4 {
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(Double(attempt) * 2))
            }
            if Task.isCancelled { break }
            do {
                let data = try await RemoteImageLoader.urlSession.data(for: url)
                await ScreenshotImageTracker.shared.end(failed: false)
                return data
            } catch {
                lastError = error
                print("Screenshot image \(url) failed (attempt \(attempt + 1)): \(error)")
            }
        }
        // A view that went away cancels its load; that is not a failure.
        await ScreenshotImageTracker.shared.end(failed: !Task.isCancelled)
        throw lastError
    }
}

/// Counts the image loads of a screenshot scene.
actor ScreenshotImageTracker {
    static let shared = ScreenshotImageTracker()

    struct Snapshot: Sendable {
        var started = 0
        var inFlight = 0
        var failed = 0
        var lastChange = Date()
    }

    private var state = Snapshot()

    func begin() {
        state.started += 1
        state.inFlight += 1
        state.lastChange = Date()
    }

    func end(failed: Bool) {
        state.inFlight -= 1
        if failed { state.failed += 1 }
        state.lastChange = Date()
    }

    func snapshot() -> Snapshot {
        state
    }

    /// Waits until images have loaded and none started or finished for `quiet` seconds.
    /// Returns false, and the scene is never reported ready, when an image failed to load.
    static func waitUntilSettled(quiet: TimeInterval = 3) async -> Bool {
        while !Task.isCancelled {
            let state = await shared.snapshot()
            if state.failed > 0 {
                print("Screenshot scene: \(state.failed) image(s) failed to load; not marking it ready")
                return false
            }
            if state.started > 0, state.inFlight == 0, Date().timeIntervalSince(state.lastChange) >= quiet {
                return true
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }
}

extension View {
    /// Tells scripts/screenshots.sh that the scene is on screen by writing `tmp/screenshot-ready`
    /// into the app container, once `isReady` is true (the live data has loaded) and every image
    /// the scene shows has loaded too. Nothing is written when loading fails, so CI fails instead
    /// of committing a broken capture.
    func signalsScreenshotReady(_ scene: ScreenshotScene?, when isReady: Bool) -> some View {
        task(id: isReady) {
            guard let scene, isReady else { return }
            // Give the views a moment to start loading their images.
            try? await Task.sleep(for: .seconds(1.5))
            guard await ScreenshotImageTracker.waitUntilSettled(), !Task.isCancelled else { return }
            let marker = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
            try? scene.rawValue.write(to: marker, atomically: true, encoding: .utf8)
            print("Screenshot scene \(scene.rawValue) is ready")
        }
    }
}
