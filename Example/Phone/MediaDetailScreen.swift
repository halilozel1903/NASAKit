import SwiftUI
import NASAKit

/// A library item's page: the image in a sharp size, then its title, facts, description and
/// keywords.
struct MediaDetailScreen: View {
    let item: NASAMediaItem
    let scene: ScreenshotScene?

    @Environment(Explorer.self) private var explorer
    @State private var imageURL: URL? = nil
    @State private var errorMessage: String? = nil

    init(item: NASAMediaItem, scene: ScreenshotScene?) {
        self.item = item
        self.scene = scene
    }

    var body: some View {
        Group {
            if let imageURL {
                content(imageURL)
            } else if let errorMessage {
                ContentUnavailableView("Couldn't load this image", systemImage: "photo", description: Text(errorMessage))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .orbitNavigationBar()
        .task(id: item.nasaID) {
            await load()
        }
        .signalsScreenshotReady(scene, when: imageURL != nil)
    }

    private func load() async {
        errorMessage = nil
        do {
            imageURL = try await explorer.image(of: item, preferring: [.medium, .large, .small])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func content(_ url: URL) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RemoteImage(url: url, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(Color.black)

                VStack(alignment: .leading, spacing: 14) {
                    Text(item.title)
                        .font(.title2.bold())
                    Text(Theme.itemFacts(item))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    if let photographer = item.metadata.photographer {
                        Label(photographer, systemImage: "camera")
                            .font(.subheadline)
                    }
                    if let description = item.metadata.plainDescription {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    if !item.metadata.keywords.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(Array(item.metadata.keywords.prefix(10)), id: \.self) { keyword in
                                    Text(keyword)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Theme.surface, in: Capsule())
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    Text(verbatim: "NASA ID " + item.nasaID)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                    if let page = item.pageURL {
                        Link(destination: page) {
                            Label("Open on images.nasa.gov", systemImage: "safari")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    CreditLine()
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
    }
}
