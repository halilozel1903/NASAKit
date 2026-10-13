import SwiftUI
import NASAKit

/// Searches the NASA Image and Video Library as you type (debounced). The `detail` screenshot
/// scene opens the first result once the results are in.
struct SearchScreen: View {
    let scene: ScreenshotScene?

    @Environment(Explorer.self) private var explorer
    @State private var query: String
    @State private var results: [NASAMediaItem] = []
    @State private var resultsQuery: String? = nil
    @State private var errorMessage: String? = nil
    @State private var path: [NASAMediaItem] = []

    init(scene: ScreenshotScene?) {
        self.scene = scene
        _query = State(initialValue: scene == nil ? "nebula" : ScreenshotScene.searchQuery)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if trimmedQuery.isEmpty {
                    ContentUnavailableView(
                        "Search NASA's library",
                        systemImage: "magnifyingglass",
                        description: Text("Photos from NASA missions, telescopes and centers.")
                    )
                    .listRowBackground(Theme.background)
                } else if let errorMessage {
                    ContentUnavailableView("Search failed", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                        .listRowBackground(Theme.background)
                } else if resultsQuery == trimmedQuery, results.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                        .listRowBackground(Theme.background)
                } else if resultsQuery != trimmedQuery {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Theme.background)
                } else {
                    ForEach(results) { item in
                        NavigationLink(value: item) {
                            LibraryRow(item: item)
                        }
                        .listRowBackground(Theme.background)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Library")
            // iOS 26 leaves the large title out with a pinned bar background; keep it inline.
            .navigationBarTitleDisplayMode(.inline)
            .orbitNavigationBar()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "NASA Image and Video Library")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .task(id: trimmedQuery) {
                await search(trimmedQuery)
            }
            .navigationDestination(for: NASAMediaItem.self) { item in
                MediaDetailScreen(item: item, scene: scene == .detail ? scene : nil)
            }
        }
        .signalsScreenshotReady(scene == .search ? scene : nil, when: resultsQuery == trimmedQuery && !results.isEmpty)
    }

    private func search(_ text: String) async {
        guard !text.isEmpty else {
            results = []
            resultsQuery = nil
            errorMessage = nil
            return
        }
        if scene == nil {
            // Wait for a pause in typing; a new keystroke cancels this task.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
        }
        do {
            let found = try await explorer.search(text)
            guard !Task.isCancelled else { return }
            results = found
            resultsQuery = text
            errorMessage = nil
            if scene == .detail, path.isEmpty, let first = found.first {
                // The detail scene opens the first result, without the push animation.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    path = [first]
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}

/// A search result: the preview image, title, center and date.
struct LibraryRow: View {
    let item: NASAMediaItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RemoteImage(url: item.previewURL)
                .frame(width: 104, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(Theme.itemFacts(item))
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                if let description = item.metadata.plainDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
