import SwiftUI
import NASAKit

/// The latest day of EPIC images: the whole sunlit side of Earth, seen from the DSCOVR
/// spacecraft. Loaded live from epic.gsfc.nasa.gov, which needs no API key.
struct TVEarthView: View {
    let scene: ScreenshotScene?
    @Environment(Explorer.self) private var explorer
    @FocusState private var focused: String?
    @State private var selectedID: String? = nil

    init(scene: ScreenshotScene?) {
        self.scene = scene
    }

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            switch explorer.earthPhase {
            case let .failed(message):
                TVMessage(title: "Couldn't load Earth images", message: message) {
                    Task { await explorer.loadEarth() }
                }
            case .loaded:
                content
            default:
                ProgressView()
            }
        }
        .task {
            if explorer.earthPhase == .idle {
                await explorer.loadEarth()
            }
        }
        .signalsScreenshotReady(scene, when: explorer.earthPhase == .loaded)
    }

    private var selected: EPICImage? {
        let images = explorer.earthImages
        return images.first { $0.id == selectedID } ?? images.last
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image = selected {
                HStack(alignment: .center, spacing: 60) {
                    RemoteImage(url: image.imageURL(.jpg), contentMode: .fit)
                        .frame(width: 620, height: 620)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    details(image)
                    Spacer(minLength: 0)
                }
            }
            rail
        }
        .padding(.horizontal, 80)
        .padding(.top, 40)
        .onChange(of: focused) { _, id in
            if let id { selectedID = id }
        }
    }

    private func details(_ image: EPICImage) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            BrandMark(size: 24)
            Text("Earth from a million miles")
                .font(.system(size: 54, weight: .heavy))
            if let day = image.day {
                Text(Theme.longDay(day) + ", " + String(day.year))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 12) {
                fact("clock", Theme.utcTime(image.date))
                fact("location", Theme.coordinates(image.centroid).map { "Centered on " + $0 })
                fact("arrow.left.and.right", Theme.kilometers(image.spacecraftDistance).map { "DSCOVR is " + $0 + " from Earth" })
            }
            if let caption = image.caption {
                Text(caption)
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: 860, alignment: .leading)
            }
            Text("\(explorer.earthImages.count) images on this day · NASA EPIC team, NOAA DSCOVR")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func fact(_ symbol: String, _ text: String?) -> some View {
        if let text {
            Label(text, systemImage: symbol)
                .font(.system(size: 26, weight: .medium))
        }
    }

    private var rail: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 30) {
                ForEach(explorer.earthImages) { image in
                    Button {
                        selectedID = image.id
                    } label: {
                        VStack(spacing: 8) {
                            RemoteImage(url: image.imageURL(.jpg), contentMode: .fit)
                                .frame(width: 150, height: 150)
                                .background(Color.black)
                                .clipShape(Circle())
                            Text(Theme.utcTime(image.date) ?? "")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(TVCardButtonStyle())
                    .focused($focused, equals: image.id)
                }
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 10)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .defaultFocus($focused, explorer.earthImages.last?.id)
    }
}
