//
//  LogoStore.swift
//  Clack
//

import CryptoKit
import Observation
import UIKit
import WebKit

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
        folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("logos", isDirectory: true)
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
        if type?.contains("svg") == true || head.contains("<svg") { return await SVGRasterizer.image(from: data) }
        return UIImage(data: data)
    }
}

/// Draws an SVG to a 256 pt square picture with a transparent background, through a web view that is never shown.
@MainActor
private final class SVGRasterizer: NSObject, WKNavigationDelegate {
    private var web: WKWebView?
    private var loaded: CheckedContinuation<Void, Never>?

    static func image(from svg: Data) async -> UIImage? {
        let job = SVGRasterizer()
        return await job.render(svg)
    }

    private func render(_ svg: Data) async -> UIImage? {
        let size = CGSize(width: 256, height: 256)
        let web = WKWebView(frame: CGRect(origin: .zero, size: size))
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.navigationDelegate = self
        self.web = web
        // A web view that isn't in a window may not draw at all: it sits in the key window, off to the side, unseen.
        let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        web.frame.origin = CGPoint(x: -1000, y: 0)
        window?.addSubview(web)
        defer { web.removeFromSuperview() }
        let html = """
        <html><body style="margin:0;background:transparent"><img style="width:256px;height:256px;object-fit:contain" \
        src="data:image/svg+xml;base64,\(svg.base64EncodedString())"></body></html>
        """
        await withCheckedContinuation { continuation in
            loaded = continuation
            web.loadHTMLString(html, baseURL: nil)
            // A page that never finishes isn't worth waiting for.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                self.finishLoading()
            }
        }
        // The picture inside the page decodes on its own time; wait for it before taking the snapshot.
        _ = try? await web.callAsyncJavaScript("await document.images[0].decode(); return true", contentWorld: .page)
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(origin: .zero, size: size)
        return try? await web.takeSnapshot(configuration: configuration)
    }

    private func finishLoading() {
        loaded?.resume()
        loaded = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finishLoading() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finishLoading() }
}
