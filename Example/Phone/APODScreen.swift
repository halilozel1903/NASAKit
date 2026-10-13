import SwiftUI
import NASAKit

/// Recent Astronomy Pictures of the Day from api.nasa.gov, newest first, with the key's remaining
/// requests from the `X-RateLimit-Remaining` header.
struct APODScreen: View {
    let scene: ScreenshotScene?
    @Environment(Explorer.self) private var explorer

    var body: some View {
        NavigationStack {
            Group {
                switch explorer.apodPhase {
                case let .failed(message):
                    ContentUnavailableView {
                        Label("Couldn't load the Picture of the Day", systemImage: "sparkles")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") {
                            Task { await explorer.loadAPOD() }
                        }
                    }
                case .loaded:
                    list
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Theme.background)
            .navigationTitle("Picture of the Day")
            .navigationBarTitleDisplayMode(.inline)
            .orbitNavigationBar()
        }
        .task {
            if explorer.apodPhase == .idle {
                await explorer.loadAPOD()
            }
        }
        .signalsScreenshotReady(scene, when: explorer.apodPhase == .loaded)
    }

    private var list: some View {
        List {
            ForEach(explorer.apodEntries) { entry in
                APODRow(entry: entry)
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
            }
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    if let limit = explorer.rateLimit {
                        Text(verbatim: "api.nasa.gov: " + limit.description + (explorer.hasPersonalKey ? "" : " (DEMO_KEY)"))
                    }
                    CreditLine()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowBackground(Theme.background)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

/// One day's picture, with its title, date and the start of the explanation.
struct APODRow: View {
    let entry: APODEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteImage(url: entry.displayImageURL)
                .frame(height: 210)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if entry.isVideo {
                        Label("Video", systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(10)
                    }
                }
            Text(Theme.longDay(entry.date))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.warm)
            Text(entry.title)
                .font(.headline)
            Text(entry.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            if let copyright = entry.copyright {
                Text(verbatim: "© " + copyright)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
