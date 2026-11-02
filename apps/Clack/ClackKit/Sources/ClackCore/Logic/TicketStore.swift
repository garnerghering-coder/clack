//
//  TicketStore.swift
//  Clack
//

import Foundation
import Observation
import CryptoKit

/// The tickets shared to Clack, kept on this phone and nowhere else (docs/IOS.md, "Sharing a ticket to Clack"): the
/// PDF in Application Support/Tickets (named by its SHA-256, so a ticket shared twice is kept once), and an index from
/// each trip (leg id) to its ticket, the page to open and the code read off that page. The folder is in the phone's
/// backup, and the files can't be read while the phone is locked. Not the same thing as `TicketPendingStore`, which
/// remembers a booking-site visit for an hour or three.
@MainActor @Observable
public final class TicketStore {
    public static let shared = TicketStore()

    public struct Entry: Codable, Hashable, Sendable {
        /// The PDF's file name in the folder.
        public var file: String
        /// The page (0-based) with this trip's ticket on it.
        public var page: Int
        public var issuer: TicketTrain.Issuer
        /// The code on that page, as the scanner reads it; nil when none was found.
        public var barcode: TicketBarcode?
        public var addedAt: Date

        public init(file: String, page: Int, issuer: TicketTrain.Issuer, barcode: TicketBarcode?, addedAt: Date = Date()) {
            self.file = file
            self.page = page
            self.issuer = issuer
            self.barcode = barcode
            self.addedAt = addedAt
        }
    }

    private let directory: URL
    /// Leg id → its ticket.
    public private(set) var entries: [String: Entry]

    public init(directory: URL? = nil) {
        let base = directory ?? (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Tickets", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        entries = (try? JSONDecoder().decode([String: Entry].self, from: Data(contentsOf: base.appendingPathComponent("index.json")))) ?? [:]
    }

    /// Keeps a ticket PDF and gives its file name. The same bytes are kept once.
    @discardableResult
    public func keep(pdf: Data) throws -> String {
        let name = Self.sha256Hex(pdf) + ".pdf"
        let url = directory.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: url.path) { try write(pdf, to: url) }
        return name
    }

    /// Ties a kept ticket to a trip, replacing any ticket it had (that one is deleted if nothing else uses it).
    public func attach(legId: String, entry: Entry) {
        let old = entries[legId]
        entries[legId] = entry
        if let old, old.file != entry.file { removeIfUnused(old.file) }
        saveIndex()
    }

    public func entry(for legId: String) -> Entry? { entries[legId] }

    /// The kept PDF of a trip's ticket.
    public func url(for legId: String) -> URL? {
        guard let entry = entries[legId] else { return nil }
        let url = directory.appendingPathComponent(entry.file)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Takes the ticket off a trip, and deletes the file once no trip uses it.
    public func detach(legId: String) {
        guard let old = entries.removeValue(forKey: legId) else { return }
        removeIfUnused(old.file)
        saveIndex()
    }

    /// Every kept ticket, gone ("Delete my data").
    public func deleteAll() {
        entries = [:]
        if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in files { try? FileManager.default.removeItem(at: file) }
        }
    }

    // MARK: Files

    private func removeIfUnused(_ file: String) {
        guard !entries.values.contains(where: { $0.file == file }) else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? write(data, to: directory.appendingPathComponent("index.json"))
    }

    private func write(_ data: Data, to url: URL) throws {
        #if os(iOS) || os(watchOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    nonisolated static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
