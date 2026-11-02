//
//  TicketStoreTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import ClackCore

@MainActor
struct TicketStoreTests {
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tickets-\(UUID().uuidString)")
    private let pdf = Data("%PDF-1.4 a ticket".utf8)

    private func files() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".pdf") }
    }

    @Test func theSameTicketIsKeptOnce() throws {
        let store = TicketStore(directory: folder)
        let a = try store.keep(pdf: pdf)
        let b = try store.keep(pdf: pdf)
        #expect(a == b)
        #expect(files() == [a])
    }

    @Test func theFileGoesWithItsLastTrip() throws {
        let store = TicketStore(directory: folder)
        let file = try store.keep(pdf: pdf)
        store.attach(legId: "1", entry: .init(file: file, page: 0, issuer: .dsb, barcode: nil))
        store.attach(legId: "2", entry: .init(file: file, page: 1, issuer: .dsb, barcode: nil))
        store.detach(legId: "1")
        #expect(files() == [file])
        #expect(store.url(for: "2") != nil)
        store.detach(legId: "2")
        #expect(files().isEmpty)
        #expect(store.entry(for: "2") == nil)
    }

    @Test func theIndexSurvivesARelaunch() throws {
        let code = TicketBarcode(format: .aztec, payload: Data([0x23, 0x55, 0x54, 0x00, 0xFF]), page: 0)
        let first = TicketStore(directory: folder)
        let file = try first.keep(pdf: pdf)
        first.attach(legId: "7", entry: .init(file: file, page: 0, issuer: .db, barcode: code))
        let again = TicketStore(directory: folder)
        #expect(again.entry(for: "7")?.barcode == code)
        #expect(again.entry(for: "7")?.issuer == .db)
    }

    @Test func deleteAllEmptiesTheFolder() throws {
        let store = TicketStore(directory: folder)
        let file = try store.keep(pdf: pdf)
        store.attach(legId: "1", entry: .init(file: file, page: 0, issuer: .sj, barcode: nil))
        store.deleteAll()
        #expect(store.entries.isEmpty)
        #expect(((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).isEmpty)
    }
}
