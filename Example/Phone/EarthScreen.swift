import SwiftUI
import NASAKit

/// The latest day of EPIC images, from epic.gsfc.nasa.gov (no API key): the selected image large,
/// the day's other images below it.
struct EarthScreen: View {
    let scene: ScreenshotScene?

    @Environment(Explorer.self) private var explorer
    @State private var selectedID: String? = nil

    init(scene: ScreenshotScene?) {
        self.scene = scene
    }

    var body: some View {
        NavigationStack {
            Group {
                switch explorer.earthPhase {
                case let .failed(message):
                    ContentUnavailableView {
                        Label("Couldn't load Earth images", systemImage: "globe")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") {
                            Task { await explorer.loadEarth() }
                        }
                    }
                case .loaded:
                    content
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Theme.background)
            .navigationTitle("Earth")
            .navigationBarTitleDisplayMode(.inline)
            .orbitNavigationBar()
        }
        .task {
            if explorer.earthPhase == .idle {
                await explorer.loadEarth()
            }
        }
        .signalsScreenshotReady(scene, when: explorer.earthPhase == .loaded)
    }

    private var selected: EPICImage? {
        explorer.earthImages.first { $0.id == selectedID } ?? explorer.earthImages.last
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = selected {
                    RemoteImage(url: image.imageURL(.jpg), contentMode: .fit)
                        .aspectRatio(1, contentMode: .fit)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        if let day = image.day {
                            Text(Theme.longDay(day) + ", " + String(day.year))
                                .font(.title3.bold())
                        }
                        if let time = Theme.utcTime(image.date) {
                            Label(time, systemImage: "clock")
                        }
                        if let center = Theme.coordinates(image.centroid) {
                            Label("Centered on " + center, systemImage: "location")
                        }
                        if let distance = Theme.kilometers(image.spacecraftDistance) {
                            Label("DSCOVR is " + distance + " from Earth", systemImage: "arrow.left.and.right")
                        }
                    }
                    .font(.subheadline)
                }

                Text("This day")
                    .font(.headline)
                    .padding(.top, 4)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                    ForEach(explorer.earthImages) { image in
                        Button {
                            selectedID = image.id
                        } label: {
                            RemoteImage(url: image.imageURL(.jpg), contentMode: .fit)
                                .aspectRatio(1, contentMode: .fit)
                                .background(Color.black)
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(Theme.accent, lineWidth: image.id == selected?.id ? 3 : 0)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Theme.utcTime(image.date) ?? image.identifier)
                    }
                }
                CreditLine(text: "Images: NASA EPIC team, NOAA DSCOVR. Not endorsed by NASA.")
            }
            .padding(16)
        }
    }
}
