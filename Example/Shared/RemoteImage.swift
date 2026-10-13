import SwiftUI
import UIKit

/// Loads the bytes of an image URL. Views load images through the loader in the environment, so
/// the screenshot scenes can count and retry their loads.
struct RemoteImageLoader: Sendable {
    private let load: @Sendable (URL) async throws -> Data

    init(_ load: @escaping @Sendable (URL) async throws -> Data) {
        self.load = load
    }

    func data(for url: URL) async throws -> Data {
        try await load(url)
    }

    /// Loads over `URLSession.shared`, keeping recent images in memory.
    static let urlSession = RemoteImageLoader { url in
        if let cached = await ImageDataCache.shared.data(for: url) {
            return cached
        }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue("NASAKit example (+https://github.com/halilozel1903/NASAKit)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard UIImage(data: data) != nil else {
            throw URLError(.cannotDecodeContentData)
        }
        await ImageDataCache.shared.insert(data, for: url)
        return data
    }
}

/// Recently loaded image bytes, so scrolling back doesn't hit the network again.
actor ImageDataCache {
    static let shared = ImageDataCache()

    private var entries: [URL: Data] = [:]
    private var order: [URL] = []
    private let limit = 120

    func data(for url: URL) -> Data? {
        entries[url]
    }

    func insert(_ data: Data, for url: URL) {
        if entries[url] == nil {
            order.append(url)
        }
        entries[url] = data
        while order.count > limit {
            entries[order.removeFirst()] = nil
        }
    }
}

/// Decoded images, so an image that scrolls back into view appears at once.
@MainActor
final class DecodedImageCache {
    static let shared = DecodedImageCache()

    private var images: [URL: Image] = [:]
    private var order: [URL] = []
    private let limit = 150

    func image(for url: URL) -> Image? {
        images[url]
    }

    func insert(_ image: Image, for url: URL) {
        if images[url] == nil {
            order.append(url)
        }
        images[url] = image
        while order.count > limit {
            images[order.removeFirst()] = nil
        }
    }
}

private struct RemoteImageLoaderKey: EnvironmentKey {
    static let defaultValue: RemoteImageLoader = .urlSession
}

extension EnvironmentValues {
    var remoteImageLoader: RemoteImageLoader {
        get { self[RemoteImageLoaderKey.self] }
        set { self[RemoteImageLoaderKey.self] = newValue }
    }
}

extension View {
    func remoteImageLoader(_ loader: RemoteImageLoader) -> some View {
        environment(\.remoteImageLoader, loader)
    }
}

/// An image from a URL that fills (or fits) the space it is given. While it loads it shows a
/// plain surface with a spinner; a failed load shows a symbol. It never shows other artwork.
struct RemoteImage: View {
    let url: URL?
    let contentMode: ContentMode

    @Environment(\.remoteImageLoader) private var loader
    @State private var loaded: LoadedImage? = nil
    @State private var failed = false

    init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }

    var body: some View {
        Theme.surface
            .overlay {
                if let image = currentImage {
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity)
                } else if failed || url == nil {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(Color.white.opacity(0.35))
                } else {
                    ProgressView()
                }
            }
            .clipped()
            .task(id: url) {
                await load()
            }
            .accessibilityHidden(true)
    }

    private var currentImage: Image? {
        guard let url else { return nil }
        if let loaded, loaded.url == url {
            return loaded.image
        }
        return DecodedImageCache.shared.image(for: url)
    }

    private func load() async {
        failed = false
        guard let url, DecodedImageCache.shared.image(for: url) == nil else { return }
        do {
            let data = try await loader.data(for: url)
            guard !Task.isCancelled else { return }
            guard let uiImage = UIImage(data: data) else {
                failed = true
                return
            }
            let image = Image(uiImage: uiImage)
            DecodedImageCache.shared.insert(image, for: url)
            withAnimation(.easeOut(duration: 0.2)) {
                loaded = LoadedImage(url: url, image: image)
            }
        } catch {
            if !Task.isCancelled {
                failed = true
            }
        }
    }
}

private struct LoadedImage {
    let url: URL
    let image: Image
}
