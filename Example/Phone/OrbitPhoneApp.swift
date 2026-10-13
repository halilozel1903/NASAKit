import SwiftUI
import NASAKit

@main
struct OrbitPhoneApp: App {
    @State private var explorer: Explorer

    init() {
        _explorer = State(initialValue: Explorer.make(for: ScreenshotScene.current))
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView(scene: ScreenshotScene.current)
                .environment(explorer)
                // Screenshot scenes count their image loads, to report ready once all are on screen.
                .remoteImageLoader(ScreenshotScene.current == nil ? RemoteImageLoader.urlSession : ScreenshotScene.imageLoader)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

/// Three tabs: library search, Earth and the Picture of the Day.
struct PhoneRootView: View {
    enum Tab: Hashable {
        case search
        case earth
        case apod
    }

    let scene: ScreenshotScene?
    @State private var tab: Tab

    init(scene: ScreenshotScene?) {
        self.scene = scene
        switch scene {
        case .earth: _tab = State(initialValue: .earth)
        case .apod: _tab = State(initialValue: .apod)
        default: _tab = State(initialValue: .search)
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            SearchScreen(scene: scene == .search || scene == .detail ? scene : nil)
                .tabItem { Label("Library", systemImage: "photo.stack") }
                .tag(Tab.search)
            EarthScreen(scene: scene == .earth ? scene : nil)
                .tabItem { Label("Earth", systemImage: "globe.americas") }
                .tag(Tab.earth)
            APODScreen(scene: scene == .apod ? scene : nil)
                .tabItem { Label("Today", systemImage: "sparkles") }
                .tag(Tab.apod)
        }
    }
}

extension View {
    /// The app's dark, opaque navigation bar. iOS 26 bars are transparent by default; an inline
    /// title over scrolled content would be unreadable.
    @MainActor
    func orbitNavigationBar() -> some View {
        toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
