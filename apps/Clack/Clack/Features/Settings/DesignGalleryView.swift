//
//  DesignGalleryView.swift
//  Clack
//

#if DEBUG
import SwiftUI

/// Debug only: every design component in both themes, for checking against the web app (docs/SWIFT_PORT.md step 4).
/// Reach it from Settings > Design, or launch with the argument `-design` (and `-light` to start in the light theme).
struct DesignGalleryView: View {
    @Environment(AppModel.self) private var app
    @State private var light = CommandLine.arguments.contains("-light")
    @State private var segment = 0
    @State private var chipActive = true
    @State private var time = "07:14"
    @State private var showSheet = false

    private let swatches: [(String, Color)] = [
        ("bg", Ink.bg), ("surface", Ink.surface), ("surface-raised", Ink.surfaceRaised), ("glass", Ink.glass),
        ("text", Ink.text), ("text-2", Ink.text2), ("text-3", Ink.text3), ("accent", Ink.accent),
        ("accent-ink", Ink.accentInk), ("accent-line", Ink.accentLine), ("on-time", Ink.onTime),
        ("on-time-ink", Ink.onTimeInk), ("slight", Ink.slight), ("slight-ink", Ink.slightInk), ("late", Ink.late),
        ("late-ink", Ink.lateInk), ("very-late", Ink.veryLate), ("very-late-ink", Ink.veryLateInk),
        ("unknown", Ink.unknown), ("hairline", Ink.hairline), ("flap-top", Ink.flapTop), ("tflap-top", Ink.tflapTop),
    ]

    private let icons = [
        "train-front", "compass", "stamp", "settings", "search", "plus", "x", "check", "clock", "map", "map-pin",
        "route", "wifi", "wifi-off", "star", "ticket", "navigation", "locate-fixed", "layers", "share-2",
        "trash", "triangle-alert", "refresh-cw", "info", "globe", "moon", "flag", "eye", "list", "chevron-right",
    ]

    /// `-section Type` scrolls to a section on launch, to check each one without scrolling by hand.
    private var startSection: String? {
        CommandLine.arguments.firstIndex(of: "-section").flatMap { index in
            CommandLine.arguments.indices.contains(index + 1) ? CommandLine.arguments[index + 1] : nil
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            page.onAppear {
                if let startSection { proxy.scrollTo(startSection, anchor: .top) }
            }
        }
    }

    private var page: some View {
        Page {
            BackLink()
            PageHeader(title: "Design") {
                IconButton(icon: light ? "moon" : "star", label: "Theme") { light.toggle() }
            }
            section("Wordmark") {
                Wordmark(fontSize: 64)
                Wordmark(fontSize: 26)
            }
            section("Colours") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(swatches, id: \.0) { name, color in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: Radius.tag).fill(color).frame(height: 36)
                                .overlay(RoundedRectangle(cornerRadius: Radius.tag).strokeBorder(Ink.hairline))
                            Text(name).clack(.mapAttribution).foregroundStyle(Ink.text2).lineLimit(1)
                        }
                    }
                }
            }
            section("Type") {
                Text("Page title 40").clack(.pageTitle).foregroundStyle(Ink.text)
                Text("Sheet title 28").clack(.sheetTitle).foregroundStyle(Ink.text)
                Text("Headline 20").clack(.headline).foregroundStyle(Ink.text)
                Text("Row title 16 semibold").clack(.rowTitle).foregroundStyle(Ink.text)
                Text("Body 16 regular, with a longer line to show wrapping and the line height of twenty-two points.")
                    .clack(.body).foregroundStyle(Ink.text)
                Text("Caption 13").clack(.caption).foregroundStyle(Ink.text2)
                Text("Section header").clack(.sectionHeader).foregroundStyle(Ink.text2)
                Text("Micro caps").clack(.captionUpper).foregroundStyle(Ink.text2)
                Text("19:04 · 455 km").clack(.heroTimes).foregroundStyle(Ink.text)
                Text("1 234 567").clack(.passportBig).foregroundStyle(Ink.text)
            }
            section("Buttons") {
                HStack(spacing: 10) {
                    Button("Primary") {}.buttonStyle(.clack(.primary))
                    Button("Secondary") {}.buttonStyle(.clack())
                    Button("Danger") {}.buttonStyle(.clack(.danger))
                }
                HStack(spacing: 10) {
                    Button("Small") {}.buttonStyle(.clack(small: true))
                    Button("Disabled") {}.buttonStyle(.clack()).disabled(true)
                    Button("Link") {}.buttonStyle(LinkButtonStyle())
                }
                Button("Wide primary") {}.buttonStyle(.clack(.primary, wide: true))
                HStack(spacing: 10) {
                    IconButton(icon: "settings", label: "Settings") {}
                    IconButton(icon: "x", label: "Close", small: true) {}
                }
                SegmentedControl(selection: $segment, options: [(0, "System"), (1, "Dark"), (2, "Light")])
            }
            section("Chips and status") {
                HStack(spacing: 14) {
                    Chip(text: "Boarding")
                    Chip(text: "Live now", accent: true)
                    PlatformChip(platform: "17b")
                    PlatformChip(platform: "4", changedFrom: "3")
                }
                HStack(spacing: 8) {
                    ChipButton(text: "Filter", active: chipActive) { chipActive.toggle() }
                    ChipButton(text: "Removable", removable: true) {}
                    Pill(text: "Pill")
                }
                HStack(spacing: 16) {
                    DelayText(delay: 0)
                    DelayText(delay: 8)
                    DelayText(delay: 22)
                    DelayText(delay: 39)
                    DelayText(delay: -2)
                    DelayText(delay: nil, canceled: true)
                    DelayText(delay: nil)
                }
            }
            section("Split-flap") {
                HStack(spacing: 16) {
                    SplitFlap(value: time, size: .time, intro: true)
                    Button("Flip") { time = time == "07:14" ? "19:48" : "07:14" }.buttonStyle(.clack(small: true))
                }
                HStack(spacing: 16) {
                    FlapTime(time: 1_792_732_440_000, tz: "Europe/Stockholm", clock: app.settings.clock, style: .lg)
                    FlapTime(time: 1_792_732_440_000 + 780_000, sched: 1_792_732_440_000, tz: "Europe/Stockholm", clock: .h24, style: .md)
                }
                HStack(spacing: 16) {
                    FlapTime(time: 1_792_732_440_000, tz: "Europe/Stockholm", clock: .h24, style: .sm)
                    FlapTime(time: 1_792_732_440_000, tz: "Europe/Stockholm", clock: .h12, style: .text)
                    FlapTime(time: 1_792_732_440_000 + 300_000, sched: 1_792_732_440_000, tz: "Europe/Stockholm", clock: .h24, style: .text)
                    FlapTime(time: nil, tz: "Europe/Stockholm", clock: .h24)
                }
            }
            section("Operator badges") {
                HStack(spacing: 12) {
                    ForEach(app.operators.prefix(6)) { OperatorBadge(op: $0, size: 36) }
                    OperatorBadge(op: nil, size: 36)
                    OperatorBadge(op: app.operators.first, size: 28)
                }
            }
            section("Surfaces") {
                Card { Text("Card").clack(.rowTitle).foregroundStyle(Ink.text); Text("The lit surface, tinted by the accent.").clack(.caption).foregroundStyle(Ink.text2) }
                Card(op: Color(hex: "#1fb14f")!) { Text("Card tinted by an operator").clack(.rowTitle).foregroundStyle(Ink.text) }
                Surface.Hero(op: Color(hex: "#f04a3a")!).frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card)).hairlineBorder(radius: Radius.card)
                Surface.Pill(op: Color(hex: "#00a07a")!).frame(height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card)).hairlineBorder(radius: Radius.card)
                Banner { Text("A neutral banner.") }
                Banner(kind: .error) { Text("Couldn't load your trips.") }
                Banner(kind: .warn) { Text("A warning banner.") }
                Skeleton()
            }
            section("Icons") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 14) {
                    ForEach(icons, id: \.self) { LucideIcon(name: $0, size: 22).foregroundStyle(Ink.text) }
                }
            }
            section("Sheet") {
                Button("Open a sheet") { showSheet = true }.buttonStyle(.clack())
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(light ? .light : .dark)
        .sheet(isPresented: $showSheet) {
            SheetFrame(title: "A sheet", onClose: { showSheet = false }) {
                Text("Body text on the surface colour.").clack(.body).foregroundStyle(Ink.text)
                Button("Primary") {}.buttonStyle(.clack(.primary, wide: true))
            }
            .preferredColorScheme(light ? .light : .dark)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).clack(.sectionHeader).foregroundStyle(Ink.text2)
            content()
        }
        .padding(.top, 8)
        .id(title)
    }
}
#endif
