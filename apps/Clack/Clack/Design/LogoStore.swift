//
//  LogoStore.swift
//  Clack
//

import ClackCore
import CryptoKit
import Observation
import UIKit

/// The operators' logos, loaded once at launch and kept in memory and on disk, so a badge shows its logo the moment it
/// appears instead of waiting for a download. A logo that is an SVG (some operators publish only that) is drawn to a
/// picture here, because `UIImage` can't read SVG.
@MainActor
@Observable
final class LogoStore {
    static let shared = LogoStore()

    private var images: [String: UIImage] = [:]
    @ObservationIgnored private var loading: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private let folder: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        // "logos-2": logos are saved here, not in the old "logos" folder, which holds pictures from an earlier drawing
        // routine that got some of them wrong (and is cleared out now).
        try? FileManager.default.removeItem(at: caches.appendingPathComponent("logos", isDirectory: true))
        folder = caches.appendingPathComponent("logos-2", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// The logo if it's here already (memory, then disk).
    func image(for url: URL) -> UIImage? {
        let key = url.absoluteString
        if let image = images[key] { return image }
        if let data = try? Data(contentsOf: file(for: key)), let image = UIImage(data: data, scale: 3) {
            images[key] = image
            return image
        }
        return nil
    }

    /// Fetches the logos that aren't here yet, all at once.
    func prefetch(_ urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls { group.addTask { await self.load(url) } }
        }
    }

    func load(_ url: URL) async {
        let key = url.absoluteString
        if image(for: url) != nil { return }
        if let task = loading[key] { return await task.value }
        let task = Task { [weak self] in
            guard let self else { return }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let image = await self.decode(data, type: response.mimeType)
            guard let image, let png = image.pngData() else { return }
            try? png.write(to: self.file(for: key), options: .atomic)
            self.images[key] = UIImage(data: png, scale: 3)
        }
        loading[key] = task
        await task.value
        loading[key] = nil
    }

    private func file(for key: String) -> URL {
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent(hash + ".png")
    }

    private func decode(_ data: Data, type: String?) async -> UIImage? {
        let head = String(decoding: data.prefix(200), as: UTF8.self).lowercased()
        if type?.contains("svg") == true || head.contains("<svg") { return SVGLogo.image(from: data) }
        return UIImage(data: data)
    }
}
