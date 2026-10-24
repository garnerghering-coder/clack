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

    /// The logo if it's in memory. Called from `OperatorBadge.body`, so it does no hashing and no disk reads: `load`
    /// brings a logo from disk or the network off the main actor and publishes it here once.
    func image(for url: URL) -> UIImage? { images[url.absoluteString] }

    /// Fetches the logos that aren't here yet, all at once.
    func prefetch(_ urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls { group.addTask { await self.load(url) } }
        }
    }

    func load(_ url: URL) async {
        let key = url.absoluteString
        if images[key] != nil { return }
        if let task = loading[key] { return await task.value }
        let file = Self.file(for: key, in: folder)
        let task = Task { [weak self] in
            let image = await Task.detached(priority: .utility) { await Self.fetch(url, file: file) }.value
            if let image { self?.images[key] = image }
        }
        loading[key] = task
        await task.value
        loading[key] = nil
    }

    /// The saved picture if there is one, otherwise the download (saved for next time). Runs off the main actor.
    private nonisolated static func fetch(_ url: URL, file: URL) async -> UIImage? {
        if let data = try? Data(contentsOf: file), let image = UIImage(data: data, scale: 3) { return image }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = decode(data, type: response.mimeType), let png = image.pngData() else { return nil }
        try? png.write(to: file, options: .atomic)
        return UIImage(data: png, scale: 3)
    }

    nonisolated static func file(for key: String, in folder: URL) -> URL {
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent(hash + ".png")
    }

    private nonisolated static func decode(_ data: Data, type: String?) -> UIImage? {
        let head = String(decoding: data.prefix(200), as: UTF8.self).lowercased()
        if type?.contains("svg") == true || head.contains("<svg") { return SVGLogo.image(from: data) }
        return UIImage(data: data)
    }
}
