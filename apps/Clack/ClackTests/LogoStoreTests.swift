//
//  LogoStoreTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import Clack

struct LogoStoreTests {
    private let folder = URL(fileURLWithPath: "/tmp/logos-test", isDirectory: true)

    @Test func fileNameIsStablePerKeyAndDiffersBetweenKeys() {
        let a = LogoStore.file(for: "https://x/a.svg", in: folder)
        #expect(a == LogoStore.file(for: "https://x/a.svg", in: folder))
        #expect(a != LogoStore.file(for: "https://x/b.svg", in: folder))
        #expect(a.pathExtension == "png")
        #expect(a.lastPathComponent.count == 64 + 4)
    }

    @MainActor @Test func lookupInMemoryIsEmptyUntilLoaded() {
        #expect(LogoStore.shared.image(for: URL(string: "https://invalid.example/none.png")!) == nil)
    }
}
