import SwiftUI
import NASAKit

/// The Discover screen: a hero image from the NASA Image and Video Library, then a rail per
/// topic. Every image is loaded live from images.nasa.gov.
struct TVHomeView: View {
    let scene: ScreenshotScene?
    @Environment(Explorer.self) private var explorer

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            switch explorer.homePhase {
            case let .failed(message):
                TVMessage(title: "Couldn't load the library", message: message) {
                    Task { await explorer.loadHome() }
                }
            default:
                if let hero = explorer.hero, explorer.homePhase == .loaded {
                    content(hero: hero)
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            if explorer.homePhase == .idle {
                await explorer.loadHome()
            }
        }
        .signalsScreenshotReady(scene, when: explorer.homePhase == .loaded)
    }

    private func content(hero: LibraryEntry) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 30) {
                TVHero(entry: hero)

                ForEach(explorer.rails) { rail in
                    TVRail(title: rail.topic.title, subtitle: "NASA Image and Video Library") {
                        ForEach(rail.entries) { entry in
                            NavigationLink(value: entry.item) {
                                TVLibraryCard(entry: entry)
                            }
                            .buttonStyle(TVCardButtonStyle())
                        }
                    }
                }

                CreditLine()
                    .padding(.horizontal, 80)
                    .padding(.bottom, 60)
            }
        }
        // The hero runs to the screen's edges; rails keep their own 80-point inset.
        .ignoresSafeArea()
    }
}

/// A library image over the whole width with its title and description.
struct TVHero: View {
    let entry: LibraryEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: entry.imageURL)
            // Opaque behind the text, so text in the image doesn't show through it.
            LinearGradient(
                stops: [
                    .init(color: Theme.background, location: 0),
                    .init(color: Theme.background.opacity(0.95), location: 0.42),
                    .init(color: Theme.background.opacity(0.5), location: 0.6),
                    .init(color: .clear, location: 0.82),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            LinearGradient(
                colors: [Theme.background, .clear],
                startPoint: .bottom,
                endPoint: UnitPoint(x: 0.5, y: 0.5)
            )

            VStack(alignment: .leading, spacing: 16) {
                BrandMark(size: 26)
                    .padding(.bottom, 14)
                Label("From the NASA Image and Video Library", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(entry.item.title)
                    .font(.system(size: 64, weight: .heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 1000, alignment: .leading)
                Text(Theme.itemFacts(entry.item))
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                if let description = entry.item.metadata.plainDescription {
                    Text(description)
                        .font(.system(size: 24))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(3)
                        .frame(maxWidth: 980, alignment: .leading)
                }
                NavigationLink(value: entry.item) {
                    Label("View Image", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .padding(.top, 10)
            }
            .padding(.leading, 80)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 660)
        .clipped()
    }
}
