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

    @Test func onlyTheLogosThatRunToTheirEdgesGetAMargin() {
        func url(_ id: String) -> URL { URL(string: "https://x.example/api/operators/\(id)/logo?v=1")! }
        for id in ["malartag", "norrtag", "oresundstag", "pagatag", "tagab", "x-taget"] { #expect(OperatorBadge.needsMargin(url(id))) }
        for id in ["sj", "vr", "tib", "varmlandstrafik", "go-ahead-norge"] { #expect(!OperatorBadge.needsMargin(url(id))) }
    }

    @MainActor @Test func lookupInMemoryIsEmptyUntilLoaded() {
        #expect(LogoStore.shared.image(for: URL(string: "https://invalid.example/none.png")!) == nil)
    }
}
