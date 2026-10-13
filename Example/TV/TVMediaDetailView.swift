import SwiftUI
import NASAKit

/// A library item's page: the image in a large size beside its title, facts, description and
/// keywords.
struct TVMediaDetailView: View {
    let item: NASAMediaItem

    @Environment(Explorer.self) private var explorer
    @State private var imageURL: URL? = nil
    @State private var errorMessage: String? = nil

    init(item: NASAMediaItem) {
        self.item = item
    }

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            if let imageURL {
                content(imageURL)
            } else if let errorMessage {
                TVMessage(title: "Couldn't load this image", message: errorMessage) {
                    Task { await load() }
                }
            } else {
                ProgressView()
            }
        }
        .task(id: item.nasaID) {
            await load()
        }
    }

    private func load() async {
        errorMessage = nil
        do {
            imageURL = try await explorer.image(of: item, preferring: [.large, .medium, .small])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func content(_ url: URL) -> some View {
        HStack(alignment: .top, spacing: 60) {
            RemoteImage(url: url, contentMode: .fit)
                .frame(width: 1000, height: 860)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            // Long descriptions scroll; the scroll view is clipped so it can't draw over the image.
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 22) {
                    Text(item.title)
                        .font(.system(size: 46, weight: .heavy))
                    Text(Theme.itemFacts(item))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    if let photographer = item.metadata.photographer {
                        Label(photographer, systemImage: "camera")
                            .font(.system(size: 24))
                    }
                    if let description = item.metadata.plainDescription {
                        Text(description)
                            .font(.system(size: 24))
                            .foregroundStyle(Color.white.opacity(0.85))
                            // Focusable, so a long description can be scrolled with the remote.
                            .focusable()
                    }
                    if !item.metadata.keywords.isEmpty {
                        Text(item.metadata.keywords.prefix(8).joined(separator: " · "))
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(verbatim: "NASA ID " + item.nasaID)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.secondary)
                        .focusable()
                    CreditLine()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipped()
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 40)
    }
}
