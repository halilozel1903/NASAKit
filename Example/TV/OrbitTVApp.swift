import SwiftUI
import NASAKit

@main
struct OrbitTVApp: App {
    @State private var explorer: Explorer

    init() {
        _explorer = State(initialValue: Explorer.make(for: ScreenshotScene.current))
    }

    var body: some Scene {
        WindowGroup {
            TVRootView(scene: ScreenshotScene.current)
                .environment(explorer)
                // Screenshot scenes count their image loads, to report ready once all are on screen.
                .remoteImageLoader(ScreenshotScene.current == nil ? RemoteImageLoader.urlSession : ScreenshotScene.imageLoader)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

/// Tabs for Discover, Earth and the Picture of the Day. A screenshot scene shows its screen on its
/// own, without the tab bar over it.
struct TVRootView: View {
    enum Tab: Hashable {
        case discover
        case earth
        case apod
    }

    let scene: ScreenshotScene?
    @State private var tab: Tab = .discover

    init(scene: ScreenshotScene?) {
        self.scene = scene
    }

    var body: some View {
        switch scene {
        case .home:
            screen { TVHomeView(scene: scene) }
        case .earth:
            screen { TVEarthView(scene: scene) }
        case .apod:
            screen { TVAPODView(scene: scene) }
        case .search, .detail, nil:
            TabView(selection: $tab) {
                screen { TVHomeView(scene: nil) }
                    .tabItem { Text("Discover") }
                    .tag(Tab.discover)
                screen { TVEarthView(scene: nil) }
                    .tabItem { Text("Earth") }
                    .tag(Tab.earth)
                screen { TVAPODView(scene: nil) }
                    .tabItem { Text("Picture of the Day") }
                    .tag(Tab.apod)
            }
        }
    }

    private func screen<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationDestination(for: NASAMediaItem.self) { item in
                    TVMediaDetailView(item: item)
                }
        }
    }
}

/// A row title and a horizontal, focusable rail of cards.
struct TVRail<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Text(title)
                    .font(.system(size: 36, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 80)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 44) {
                    content
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 34)
            }
            .scrollIndicators(.hidden)
            // Focused cards grow; let them draw outside the rail.
            .scrollClipDisabled()
            .focusSection()
        }
    }
}

/// A focus effect that scales the card without the system's parallax, which would crop the
/// caption below the image.
struct TVCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        TVCardButtonBody(configuration: configuration)
    }
}

private struct TVCardButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .scaleEffect(isFocused ? 1.08 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .shadow(color: Color.black.opacity(isFocused ? 0.6 : 0), radius: 22, x: 0, y: 16)
            .zIndex(isFocused ? 1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isFocused)
    }
}

/// A library item's image with its title and facts below it.
struct TVLibraryCard: View {
    let entry: LibraryEntry
    var width: CGFloat = 400

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RemoteImage(url: entry.imageURL)
                .frame(width: width, height: width * 9 / 16)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(isFocused ? 0.9 : 0), lineWidth: 4)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.item.title)
                    .font(.system(size: 24, weight: .semibold))
                    .lineLimit(2, reservesSpace: true)
                Text(Theme.itemFacts(entry.item))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: width, alignment: .leading)
        }
    }
}

/// A full-screen message with a retry button.
struct TVMessage: View {
    let title: String
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.bold())
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 900)
            Button("Try Again", action: retry)
        }
    }
}
