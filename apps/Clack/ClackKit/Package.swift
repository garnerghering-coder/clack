// swift-tools-version: 6.4
//
// ClackKit: what the app, its widgets and Live Activity (and a watch app later) share.
// - ClackCore: models, logic, the API client, the phone's id, the strings. Foundation only.
// - ClackDesign: the design tokens, fonts helper, icons and small views every target draws with.
//
// The Swift settings mirror the app target's (Swift 5 mode with Approachable Concurrency and member import visibility),
// except the default actor isolation: the app's is MainActor, the package's is nonisolated (as the widget extension's),
// because the widgets and a watch app call into it from their own contexts. Types that hold UI state are marked
// @MainActor themselves (L10n, LiveHub).
//
// macOS is listed only so `swift test` can run the tests on the Mac; nothing ships for it.

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5),
    // What SWIFT_APPROACHABLE_CONCURRENCY = YES turns on in the app's targets.
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InferSendableFromCaptures"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    // SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES.
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "ClackKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "ClackCore", targets: ["ClackCore"]),
    ],
    targets: [
        .target(
            name: "ClackCore",
            resources: [.process("Resources/i18n")],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ClackCoreTests",
            dependencies: ["ClackCore"],
            resources: [.copy("Fixtures")],
            swiftSettings: swiftSettings
        ),
    ]
)
