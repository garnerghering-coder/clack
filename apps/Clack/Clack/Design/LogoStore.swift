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
    /// The colour at each logo's edge, when the edge is one colour: the badge's margin is filled with it.
    private var edges: [String: UIColor] = [:]
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

    /// The logo's edge colour, once it is loaded; nil when its edge is clear or not one colour (the badge stays white).
    func edgeColor(for url: URL) -> UIColor? { edges[url.absoluteString] }

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
            let loaded = await Task.detached(priority: .utility) { () -> (UIImage, UIColor?)? in
                guard let image = await Self.fetch(url, file: file) else { return nil }
                return (image, Self.edgeColor(of: image))
            }.value
            if let (image, edge) = loaded {
                if let edge { self?.edges[key] = edge }
                self?.images[key] = image
            }
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

    /// The colour along a logo's edge when most of it is one colour: drawn small, the outer two rings of pixels are
    /// bucketed by colour and the biggest bucket wins if it holds 60% of them. Nil when the edge is mostly clear (a
    /// logo drawn for any background) or mixed (a mark that runs to the edge).
    nonisolated static func edgeColor(of image: UIImage) -> UIColor? {
        guard let cg = image.cgImage else { return nil }
        let n = 32
        var px = [UInt8](repeating: 0, count: n * n * 4)
        let drawn = px.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(
                data: buffer.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
            return true
        }
        guard drawn else { return nil }
        var buckets: [Int: (count: Int, r: Int, g: Int, b: Int)] = [:]
        var total = 0
        for y in 0..<n {
            for x in 0..<n where min(x, y, n - 1 - x, n - 1 - y) < 2 {
                total += 1
                let o = (y * n + x) * 4
                let a = Int(px[o + 3])
                guard a >= 200 else { continue }
                // Back from premultiplied.
                let r = Int(px[o]) * 255 / a, g = Int(px[o + 1]) * 255 / a, b = Int(px[o + 2]) * 255 / a
                let key = (min(r, 255) >> 4) << 8 | (min(g, 255) >> 4) << 4 | (min(b, 255) >> 4)
                let old = buckets[key] ?? (0, 0, 0, 0)
                buckets[key] = (old.count + 1, old.r + r, old.g + g, old.b + b)
            }
        }
        guard total > 0, let top = buckets.values.max(by: { $0.count < $1.count }), top.count * 10 >= total * 6 else { return nil }
        let c = Double(top.count) * 255
        return UIColor(red: min(1, Double(top.r) / c), green: min(1, Double(top.g) / c), blue: min(1, Double(top.b) / c), alpha: 1)
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
