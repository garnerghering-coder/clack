//
//  ActivityGalleryView.swift
//  Clack
//

#if DEBUG
import ClackCore
import ClackDesign
import SwiftUI

/// Debug only: every face of the trip card (ClackDesign `TripCard.swift`) for every moment, drawn inside the island's
/// shapes at Apple's sizes (Human Interface Guidelines, Live Activities, iOS dimensions: compact 52.33 x 36.67 per side,
/// minimal 36.67, expanded 371 x up to 160, the narrow island's 28 pt circle), so anything that would be cut off shows.
/// The black shapes clip like the island does; the outline inside each is the content margin the card asks for. The
/// system's own margins aren't published, so the compact sides use an estimate (`compactInset`); the simulator and a
/// phone have the last word. Reach it from Settings > Test alerts, or launch with `-activityGallery` (`-long` uses long
/// station names, `-seat` adds a car and seat).
struct ActivityGalleryView: View {
    @Environment(L10n.self) private var l10n
    @Environment(AppModel.self) private var app
    @State private var model = TestAlertsModel()
    @State private var long = CommandLine.arguments.contains("-long")
    @State private var seat = CommandLine.arguments.contains("-seat")

    /// The camera cutout in the island (about 125 x 37 pt on the Pro phones).
    private let camera = CGSize(width: 125, height: 36.67)
    /// How far in from the island's outer end the system puts a compact side's content (an estimate: not published).
    private let compactInset: CGFloat = 8

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Toggle("Long station names", isOn: $long)
                Toggle("Car and seat", isOn: $seat)
                ForEach(TestAlertsModel.Moment.allCases, id: \.self) { m in
                    moment(m)
                }
            }
            .padding(16)
        }
        .background(Ink.bg)
        .navigationTitle("Trip card faces")
    }

    private func face(_ m: TestAlertsModel.Moment) -> TripCardFace {
        var state = model.state(m)
        if seat { state.coach = "14"; state.seat = "123" }
        let start = TripCardStart(
            legId: "gallery", train: "7205", from: long ? "Stockholm Centralstation" : "Nässjö C",
            to: long ? "Göteborg Centralstation" : "Jönköping C", fromTz: "Europe/Stockholm", toTz: "Europe/Stockholm",
            color: "#2ea44f"
        )
        return TripCardFace(start: start, state: state, l10n: l10n, clock: app.settings.clock)
    }

    private func moment(_ m: TestAlertsModel.Moment) -> some View {
        let card = face(m)
        return VStack(alignment: .leading, spacing: 12) {
            Text(m.rawValue).clack(.sectionHeader).foregroundStyle(Ink.text2)
            island { expanded(card) }
            HStack(spacing: 16) {
                compact(card)
                minimal(card)
                limited(card)
            }
            lockScreen(card)
            small(card)
        }
    }

    // MARK: the island

    /// Black like the island, in the dark scheme the island always uses.
    private func island<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().environment(\.colorScheme, .dark)
    }

    private func expanded(_ card: TripCardFace) -> some View {
        let m = TripIsland.expandedMargins
        let size = TripIsland.expandedSize
        let side = (size.width - camera.width) / 2 - m.leading
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 0) {
                TripIslandExpandedLeading(card: card).frame(width: side - 4, alignment: .leading)
                Spacer(minLength: camera.width + 8)
                TripIslandExpandedTrailing(card: card).frame(width: side - 4, alignment: .trailing)
            }
            .frame(height: camera.height - m.top)
            TripIslandExpandedBottom(card: card, stale: false).environment(l10n)
        }
        .padding(m)
        .frame(width: size.width, alignment: .top)
        .frame(maxHeight: size.height, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .background(alignment: .top) { cameraShape.padding(.top, 0) }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .overlay(alignment: .bottomTrailing) { heightNote }
    }

    private var heightNote: some View {
        Text(verbatim: "≤ 160").clack(.captionUpper).foregroundStyle(Ink.text3).padding(4)
    }

    private var cameraShape: some View {
        RoundedRectangle(cornerRadius: camera.height / 2, style: .continuous)
            .stroke(Ink.hairline, lineWidth: 1)
            .frame(width: camera.width, height: camera.height)
    }

    private func compact(_ card: TripCardFace) -> some View {
        let s = TripIsland.compactSize
        return island {
            HStack(spacing: 0) {
                TripIslandCompactLeading(card: card)
                    .frame(width: s.width - compactInset, height: s.height, alignment: .trailing)
                    .padding(.leading, compactInset)
                cameraShape.frame(width: camera.width * 0.5)
                TripIslandCompactTrailing(card: card)
                    .frame(width: s.width - compactInset, height: s.height, alignment: .leading)
                    .padding(.trailing, compactInset)
            }
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: s.height / 2, style: .continuous))
        }
    }

    private func minimal(_ card: TripCardFace) -> some View {
        let s = TripIsland.minimalSize
        return island {
            ZStack {
                Circle().fill(Color.black)
                Circle().stroke(Ink.hairline, style: StrokeStyle(lineWidth: 1, dash: [2, 2])).frame(width: TripIsland.limitedCircle, height: TripIsland.limitedCircle)
                TripIslandMinimal(card: card)
            }
            .frame(width: s.width, height: s.height)
            .clipShape(Circle())
        }
    }

    /// The narrow island: the left side alone, inside the 28 pt circle; the right side is hidden.
    private func limited(_ card: TripCardFace) -> some View {
        island {
            ZStack {
                Circle().fill(Color.black)
                TripIslandCompactLeading(card: card, limited: true)
            }
            .frame(width: TripIsland.limitedCircle, height: TripIsland.limitedCircle)
            .clipShape(Circle())
        }
    }

    // MARK: the cards

    private func lockScreen(_ card: TripCardFace) -> some View {
        TripCardLockScreen(card: card, stale: true)
            .environment(l10n)
            .frame(width: TripIsland.lockScreenWidth)
            .background(Ink.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
    }

    /// The Apple Watch Smart Stack size (41 mm: 165 x 72.5 pt), also CarPlay's.
    private func small(_ card: TripCardFace) -> some View {
        TripCardSmall(card: card, stale: false)
            .environment(l10n)
            .frame(width: 165, height: 72.5)
            .background(Ink.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .environment(\.colorScheme, .dark)
    }
}
#endif
