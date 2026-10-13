import SwiftUI
import NASAKit

/// Recent Astronomy Pictures of the Day: the newest as the hero, the days before in a rail.
/// Videos show their thumbnail; entries with nothing to show are left out. Needs api.nasa.gov,
/// so it uses the `NASA_API_KEY` environment variable when set and `DEMO_KEY` otherwise (the
/// screenshot scene never uses `DEMO_KEY`).
struct TVAPODView: View {
    let scene: ScreenshotScene?
    @Environment(Explorer.self) private var explorer
    @State private var selectedDay: CalendarDate? = nil
    @FocusState private var focused: CalendarDate?

    init(scene: ScreenshotScene?) {
        self.scene = scene
    }

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            switch explorer.apodPhase {
            case let .failed(message):
                TVMessage(title: "Couldn't load the Picture of the Day", message: message) {
                    Task { await explorer.loadAPOD() }
                }
            case .loaded:
                content
            default:
                ProgressView()
            }
        }
        .task {
            if explorer.apodPhase == .idle {
                await explorer.loadAPOD()
            }
        }
        .signalsScreenshotReady(scene, when: explorer.apodPhase == .loaded)
    }

    private var selected: APODEntry? {
        explorer.apodEntries.first { $0.date == selectedDay } ?? explorer.apodEntries.first
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let entry = selected {
                hero(entry)
            }
            rail
        }
        .ignoresSafeArea(edges: .top)
        .onChange(of: focused) { _, day in
            if let day { selectedDay = day }
        }
    }

    private func hero(_ entry: APODEntry) -> some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: entry.displayImageURL)
            LinearGradient(
                stops: [
                    .init(color: Theme.background, location: 0),
                    .init(color: Theme.background.opacity(0.92), location: 0.4),
                    .init(color: .clear, location: 0.75),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            LinearGradient(colors: [Theme.background, .clear], startPoint: .bottom, endPoint: UnitPoint(x: 0.5, y: 0.55))

            VStack(alignment: .leading, spacing: 14) {
                BrandMark(size: 24)
                    .padding(.bottom, 10)
                Label(Theme.longDay(entry.date) + ", " + String(entry.date.year), systemImage: entry.isVideo ? "play.rectangle" : "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.warm)
                Text(entry.title)
                    .font(.system(size: 60, weight: .heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 1000, alignment: .leading)
                Text(entry.explanation)
                    .font(.system(size: 23))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(4)
                    .frame(maxWidth: 940, alignment: .leading)
                if let copyright = entry.copyright {
                    Text(verbatim: "© " + copyright)
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 80)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 720)
        .clipped()
    }

    private var rail: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 36) {
                ForEach(explorer.apodEntries) { entry in
                    Button {
                        selectedDay = entry.date
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            RemoteImage(url: entry.displayImageURL)
                                .frame(width: 280, height: 158)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    if entry.isVideo {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 30))
                                            .padding(10)
                                    }
                                }
                            Text(Theme.shortDay(entry.date))
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(TVCardButtonStyle())
                    .focused($focused, equals: entry.date)
                }
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .defaultFocus($focused, explorer.apodEntries.first?.date)
    }
}
