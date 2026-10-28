//
//  WalkStore.swift
//  Clack
//

import ClackCore
import Foundation
import StoreKit

/// The walks on this phone (owner test tool): each a compressed `WalkLog` file in Documents/walks, kept until deleted,
/// and uploaded to the server (`PUT /api/walklogs/:id`) after it ends and after every edit, retrying until it goes
/// through (stations underground have no signal). The server keeps only the latest version of each walk.
@MainActor
@Observable
final class WalkStore {
    /// One for the app: a walk keeps recording and uploading when you leave the screen.
    static let shared = WalkStore()

    struct Entry: Identifiable, Hashable {
        let id: String
        var title: String
        var startedAt: Double
        var duration: Double
        var routes: Int
        var marks: Int
        var bytes: Int
        var uploaded: Bool
    }

    private(set) var entries: [Entry] = []
    private(set) var uploading: Set<String> = []
    private(set) var lastError: String?
    var client: APIClient?

    private let dir: URL
    /// Walk ids whose latest version is on the server (a small file beside the walks).
    private var uploaded: Set<String>

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dir = docs.appending(path: "walks", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        uploaded = Set((try? JSONDecoder().decode([String].self, from: Data(contentsOf: dir.appending(path: "uploaded.json")))) ?? [])
        reload()
    }

    func fileURL(_ id: String) -> URL { dir.appending(path: "\(id).walk") }

    /// A copy with a readable name for sharing (AirDrop, Files, Mail): JSON, not compressed.
    func exportURL(_ id: String) -> URL? {
        guard let log = load(id), let json = try? JSONEncoder().encode(log) else { return nil }
        let safe = log.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appending(path: "Clack walk – \(safe).json")
        return (try? json.write(to: url)) != nil ? url : nil
    }

    func load(_ id: String) -> WalkLog? {
        guard let data = try? Data(contentsOf: fileURL(id)) else { return nil }
        return try? WalkLog.decompress(data)
    }

    /// Saves a walk (while it runs, and after edits). A saved walk counts as not uploaded until the next upload.
    func save(_ log: WalkLog) {
        guard let data = try? log.compressed() else { return }
        try? data.write(to: fileURL(log.id), options: .atomic)
        markUploaded(log.id, false)
        reload()
    }

    /// Saves an edited walk and uploads it again.
    func update(_ log: WalkLog) {
        save(log)
        upload(log.id)
    }

    func delete(_ id: String) {
        try? FileManager.default.removeItem(at: fileURL(id))
        markUploaded(id, false)
        reload()
    }

    func reload() {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        entries = files.filter { $0.pathExtension == "walk" }.compactMap { url in
            let id = url.deletingPathExtension().lastPathComponent
            guard let log = load(id) else { return nil }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return Entry(id: id, title: log.title, startedAt: log.startedAt, duration: log.duration(), routes: log.routes.count,
                         marks: log.markCount, bytes: size, uploaded: uploaded.contains(id))
        }
        .sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: - Upload

    func upload(_ id: String) {
        guard let client, !uploading.contains(id), let data = try? Data(contentsOf: fileURL(id)) else { return }
        uploading.insert(id)
        Task {
            defer { uploading.remove(id) }
            do {
                try await client.upload(["walklogs", id], data: data)
                markUploaded(id, true)
                lastError = nil
            } catch {
                lastError = "Upload failed (\(error.localizedDescription)); it will try again."
            }
            reload()
        }
    }

    /// Every finished walk not yet on the server (called when the list shows, and every minute while it does).
    func uploadPending(except running: String?) {
        for e in entries where !e.uploaded && e.id != running { upload(e.id) }
    }

    private func markUploaded(_ id: String, _ done: Bool) {
        if done { uploaded.insert(id) } else { uploaded.remove(id) }
        try? JSONEncoder().encode(Array(uploaded)).write(to: dir.appending(path: "uploaded.json"))
    }

    // MARK: - Who sees the tool

    /// Shows the test tools in every build while Clack is only on TestFlight (owner, 2026-10-28: the StoreKit check
    /// below never showed them there). Set to false before the first App Store release (docs/APP_STORE.md).
    static let alwaysShowTestTools = true

    /// The walk tools show in debug builds and TestFlight builds (StoreKit reports TestFlight as the sandbox), never in
    /// App Store builds.
    static func isTestBuild() async -> Bool {
        if alwaysShowTestTools { return true }
        #if DEBUG
        return true
        #else
        guard let result = try? await AppTransaction.shared else { return false }
        switch result {
        case .verified(let t), .unverified(let t, _): return t.environment == .sandbox || t.environment == .xcode
        }
        #endif
    }
}
