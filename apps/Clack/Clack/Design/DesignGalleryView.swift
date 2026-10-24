//
//  DesignGalleryView.swift
//  Clack
//

#if DEBUG
import ClackCore
import ClackDesign
import SwiftUI

/// Debug only: every design token and component, in either theme (docs/SWIFT_PORT.md step 4, DESIGN §2.5). Reach it from
/// Settings > Design, or launch with the argument `-design` (and `-light` to start in the light theme; `-section
/// StopTimeline` scrolls to a section). The samples are made-up shapes for checking the look, never shown as data.
struct DesignGalleryView: View {
    @Environment(AppModel.self) private var app
    @State private var light = CommandLine.arguments.contains("-light")
    @State private var segment = 0
    @State private var chipActive = true
    @State private var time = "07:14"
    @State private var showSheet = false
    @State private var query = ""
    @State private var favourite = true
    @State private var progress = 0.42

    /// A fixed moment for the samples (a Friday morning), so every run looks the same.
    private let t = 1_792_732_440_000.0
    private let tz = "Europe/Stockholm"
    private let minute = 60_000.0

    private let swatches: [(String, Color)] = [
        ("bg", Ink.bg), ("surface", Ink.surface), ("surface-raised", Ink.surfaceRaised), ("glass", Ink.glass),
        ("text", Ink.text), ("text-2", Ink.text2), ("text-3", Ink.text3), ("accent", Ink.accent),
        ("accent-ink", Ink.accentInk), ("accent-line", Ink.accentLine), ("on-time", Ink.onTime),
        ("on-time-ink", Ink.onTimeInk), ("slight", Ink.slight), ("slight-ink", Ink.slightInk), ("late", Ink.late),
        ("late-ink", Ink.lateInk), ("very-late", Ink.veryLate), ("very-late-ink", Ink.veryLateInk),
        ("unknown", Ink.unknown), ("hairline", Ink.hairline), ("flap-top", Ink.flapTop), ("tflap-top", Ink.tflapTop),
        ("brand-yellow", Ink.brandYellow),
    ]

    private let icons = [
        "train-front", "compass", "stamp", "settings", "search", "plus", "x", "check", "clock", "map", "map-pin",
        "route", "wifi", "wifi-off", "star", "ticket", "navigation", "locate-fixed", "layers", "share-2",
        "trash", "triangle-alert", "refresh-cw", "info", "globe", "moon", "flag", "eye", "list", "chevron-down",
    ]

    /// `-section Type` scrolls to a section on launch, to check each one without scrolling by hand.
    private var startSection: String? {
        CommandLine.arguments.firstIndex(of: "-section").flatMap { index in
            CommandLine.arguments.indices.contains(index + 1) ? CommandLine.arguments[index + 1] : nil
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            page.task {
                // After the first layout: the page is lazy, so the section exists only once the list has been laid out.
                guard let startSection else { return }
                try? await Task.sleep(for: .milliseconds(600))
                proxy.scrollTo(startSection, anchor: .top)
            }
        }
    }

    private var page: some View {
        Page {
            BackLink()
            PageHeader(title: "Design") {
                IconButton(icon: light ? "moon" : "star", label: "Theme") { light.toggle() }
            }
            tokens
            components
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

    // MARK: tokens

    @ViewBuilder
    private var tokens: some View {
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
            Text("SJ 529 · train number").clack(.trainNumber).foregroundStyle(Ink.text)
            Text("Section header").clack(.sectionHeader).foregroundStyle(Ink.text2)
            Text("Micro caps").clack(.captionUpper).foregroundStyle(Ink.text2)
            Text("Micro 11").clack(.micro).foregroundStyle(Ink.text2)
            Text("08:03").clack(.struck).strikethrough().foregroundStyle(Ink.text3)
            Text("19:04 · 455 km").clack(.heroTimes).foregroundStyle(Ink.text)
            Text("1 234 567").clack(.passportBig).foregroundStyle(Ink.text)
        }
        section("Buttons") {
            HStack(spacing: 12) {
                Button("Primary") {}.buttonStyle(.clack(.primary))
                Button("Secondary") {}.buttonStyle(.clack())
                Button("Danger") {}.buttonStyle(.clack(.danger))
            }
            HStack(spacing: 12) {
                Button("Small") {}.buttonStyle(.clack(small: true))
                Button("Disabled") {}.buttonStyle(.clack()).disabled(true)
                Button("Link") {}.buttonStyle(LinkButtonStyle())
            }
            Button("Wide primary") {}.buttonStyle(.clack(.primary, wide: true))
            SegmentedControl(selection: $segment, options: [(0, "System"), (1, "Dark"), (2, "Light")])
            HStack(spacing: 8) {
                ChipButton(text: "Filter", active: chipActive) { chipActive.toggle() }
                ChipButton(text: "Removable", removable: true) {}
            }
        }
        section("Delay") {
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
                FlapTime(time: t, tz: tz, clock: app.settings.clock, style: .lg)
                FlapTime(time: t + 13 * minute, sched: t, tz: tz, clock: .h24, style: .md)
            }
            HStack(spacing: 16) {
                FlapTime(time: t, tz: tz, clock: .h24, style: .sm)
                FlapTime(time: t, tz: tz, clock: .h12, style: .text)
                FlapTime(time: t + 5 * minute, sched: t, tz: tz, clock: .h24, style: .text)
                FlapTime(time: nil, tz: tz, clock: .h24)
            }
        }
        section("Surfaces") {
            Card { Text("Card").clack(.rowTitle).foregroundStyle(Ink.text); Text("A flat card: most of the app.").clack(.caption).foregroundStyle(Ink.text2) }
            Card(lit: true) { Text("Lit card").clack(.rowTitle).foregroundStyle(Ink.text); Text("Only hero and featured surfaces glow.").clack(.caption).foregroundStyle(Ink.text2) }
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 16) {
                ForEach(icons, id: \.self) { LucideIcon(name: $0, size: 20).foregroundStyle(Ink.text) }
                LucideIcon(name: "star", size: 20, filled: true).foregroundStyle(Ink.accentInk)
            }
        }
    }

    // MARK: components (DESIGN §2.5)

    @ViewBuilder
    private var components: some View {
        section("StopTimeline") {
            Card {
                let color = Color(hex: "#1fb14f")!
                ClackDesign.StopRow(
                    name: "Stockholm C", notes: [.init("You got on here", .accent)],
                    rail: ClackDesign.StopRail(color: color, big: true, startsHere: true, below: .init(ridden: true, fill: 1)),
                    time: t + 2 * minute, sched: t, live: true, delay: 2, tz: tz, clock: .h24, platform: "12"
                )
                ClackDesign.StopRow(
                    name: "Södertälje Syd",
                    rail: ClackDesign.StopRail(color: color, above: .init(ridden: true, fill: 1), below: .init(ridden: true, fill: 0.4, train: 0.4)),
                    time: t + 22 * minute, sched: t + 18 * minute, live: true, delay: 4, tz: tz, clock: .h24, platform: "3", platformChanged: true
                )
                ClackDesign.StopRow(
                    name: "Katrineholm C", canceled: true,
                    rail: ClackDesign.StopRail(color: color, above: .init(ridden: true), below: .init(ridden: true)),
                    time: t + 52 * minute, tz: tz, clock: .h24, platform: "1"
                )
                ClackDesign.StopRow(
                    name: "Hallsberg", notes: [.init("You get off here", .accent)],
                    rail: ClackDesign.StopRail(color: color, big: true, endsHere: false, above: .init(ridden: true), below: .init()),
                    time: t + 75 * minute, tz: tz, clock: .h24, platform: "4"
                )
                ClackDesign.StopRow(
                    name: "Örebro C", emphasis: .dim,
                    rail: ClackDesign.StopRail(color: color, ridden: false, endsHere: true, above: .init()),
                    time: t + 95 * minute, tz: tz, clock: .h24
                )
            }
            Text("Compact").clack(.captionUpper).foregroundStyle(Ink.text2)
            Card {
                let color = Color(hex: "#f04a3a")!
                ClackDesign.StopRow(name: "Malmö C", rail: ClackDesign.StopRail(color: color, big: true, startsHere: true, below: .init(ridden: true, fill: 1)), time: t, tz: tz, clock: .h24, compact: true)
                ClackDesign.StopRow(name: "Lund C", emphasis: .next, rail: ClackDesign.StopRail(color: color, above: .init(ridden: true, fill: 1), below: .init(ridden: true)), time: t + 13 * minute, sched: t + 11 * minute, live: true, delay: 2, tz: tz, clock: .h24, platform: "2", compact: true)
                ClackDesign.StopRow(name: "Hässleholm C", rail: ClackDesign.StopRail(color: color, big: true, endsHere: true, above: .init(ridden: true)), time: t + 40 * minute, tz: tz, clock: .h24, compact: true)
            }
        }
        section("BoardRow") {
            VStack(spacing: 0) {
                BoardRowView(.init(time: t, sched: t, tz: tz, destination: "Göteborg C", via: "Via Skövde C", service: "SJ 431 · X 2000", platform: "14"), clock: .h24) {
                    OperatorBadge(op: app.operators.first, size: .small)
                }
                Divider().overlay(Ink.hairline)
                BoardRowView(.init(time: t + 9 * minute, sched: t + 4 * minute, tz: tz, destination: "Uppsala C", service: "SL 2241", notes: "Signal fault", platform: "5", platformFrom: "3", delay: 5), clock: .h24)
                Divider().overlay(Ink.hairline)
                BoardRowView(.init(time: t + 12 * minute, sched: t + 12 * minute, tz: tz, destination: "Malmö C", service: "SJ 541", platform: "17b", canceled: true), clock: .h24)
            }
            Text("Compact").clack(.captionUpper).foregroundStyle(Ink.text2)
            BoardRowView(.init(time: t, sched: t, tz: tz, destination: "Göteborg C", platform: "14", delay: 0), clock: .h24, compact: true)
            BoardRowView(.init(time: t + 8 * minute, sched: t + 4 * minute, tz: tz, destination: "Uppsala C", platform: "5", delay: 4), clock: .h24, compact: true)
        }
        section("StatusLine") {
            FlowLayout(spacing: 16, lineSpacing: 8) {
                StatusLine(.live, "Live")
                StatusLine(.stale, "Stale · updated 3 min ago")
                StatusLine(.upcoming, "Departs in 2h 5m")
                StatusLine(.boarding, "Boarding")
                StatusLine(.onItsWay, "On its way")
                StatusLine(.arrived, "Arrived")
                StatusLine(.cancelled, "Cancelled")
                StatusLine(.estimated, "Estimated")
                StatusLine(.band(.slight), "Tight · 6 min spare")
            }
        }
        section("ServiceHeader") {
            ForEach(BadgeSize.allCases, id: \.self) { size in
                ServiceHeader(op: app.operators.first, number: "529", size: size, category: "intercity") {
                    StatusLine(.live, "Live")
                }
            }
            ServiceHeader(op: nil, number: "8736", size: .medium)
            HStack(spacing: 12) {
                ForEach(app.operators.prefix(6)) { OperatorBadge(op: $0, size: .large) }
                OperatorBadge(op: nil, size: .large)
            }
        }
        section("TimePair") {
            TimePair(dep: .init(time: t, sched: t, tz: tz), arr: .init(time: t + 168 * minute, sched: t + 168 * minute, tz: tz), clock: .h24)
                .clack(.body).foregroundStyle(Ink.text)
            TimePair(dep: .init(time: t + 4 * minute, sched: t, tz: tz), arr: .init(time: t + 900 * minute, sched: t + 890 * minute, tz: tz), clock: .h24)
                .clack(.caption).foregroundStyle(Ink.text2)
            TimePair(dep: .init(time: t, sched: t, tz: tz), arr: .init(time: nil, tz: tz), clock: .h12)
                .clack(.caption).foregroundStyle(Ink.text2)
            TimePair(dep: .init(time: t, sched: t, tz: tz), arr: .init(time: t + 168 * minute, sched: t + 160 * minute, tz: tz), clock: .h24, flap: .lg)
                .clack(.heroTimes)
        }
        section("Tile") {
            HStack(spacing: 12) {
                ClackDesign.Tile(label: "Distance", value: "455 km")
                ClackDesign.Tile(label: "Duration", value: "2h 48m")
                ClackDesign.Tile(label: "Delay") { DelayText(delay: 8) }
            }
            ClackDesign.Tile(label: "Longest trip", value: "1 271 km", sub: "Stockholm C → Narvik")
        }
        section("ProgressBar") {
            ProgressBar(value: progress, color: Color(hex: "#1fb14f")!, marker: .solid)
            ProgressBar(value: progress, color: Color(hex: "#f04a3a")!, marker: .hollow)
            ProgressBar(value: 0.8, previous: 0.55)
            SegmentedBar(segments: [
                .init(id: "on", count: 12, color: DelayBand.onTime.fill), .init(id: "slight", count: 5, color: DelayBand.slight.fill),
                .init(id: "late", count: 2, color: DelayBand.late.fill), .init(id: "very", count: 1, color: DelayBand.veryLate.fill),
            ])
            Button("Move") { progress = progress > 0.5 ? 0.2 : 0.8 }.buttonStyle(.clack(small: true))
        }
        section("IconButton") {
            HStack(spacing: 12) {
                IconButton(icon: "settings", label: "Settings") {}
                IconButton(icon: "plus", label: "Add a train") {}
                IconButton(icon: "star", label: "Favourite", selected: favourite) { favourite.toggle() }
                IconButton(icon: "x", label: "Close", size: .overMap) {}
                MapButton(icon: "layers", label: "Layers") {}
            }
        }
        section("SearchField") {
            SearchField(text: $query, prompt: "Train number, route, or operator")
            ZStack {
                Ink.mapBg.frame(height: 72)
                SearchField(text: $query, prompt: "Search trains and stations", overMap: true).padding(.horizontal, 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        }
        section("InfoNote") {
            InfoNote("Scheduled times only.")
            InfoNote("Times: Trafikverket.", more: "Times and platforms come from Trafikverket's open data; stops abroad come from the timetable only.")
        }
        section("PlatformTag") {
            HStack(spacing: 12) {
                PlatformTag(platform: "17b")
                PlatformTag(platform: "4", changedFrom: "3")
                PlatformTag(platform: "2", changedFrom: "")
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).clack(.sectionHeader).foregroundStyle(Ink.text2)
            content()
        }
        .padding(.top, 8)
        .id(title)
    }
}
#endif
