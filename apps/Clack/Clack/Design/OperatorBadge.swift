//
//  OperatorBadge.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// What the badge needs from an operator: both `Operator` and the trimmed one a leg carries have it.
protocol OperatorDisplay {
    var name: String { get }
    var shortName: String { get }
    var brandColor: String { get }
    var logoUrl: String? { get }
}

extension Operator: OperatorDisplay {}
extension LegOperator: OperatorDisplay {}

/// The operator's logo when there is one (the operators have approved it: `Config.showOperatorLogos`), otherwise a
/// rounded square in the brand colour with the short name in white (OperatorBadge.tsx). An operator that isn't known
/// gets the theme's strong colour (yellow on dark, black on light) with "?" in the background's colour. Three sizes
/// only; the radius is `Radius.badge` at 36 pt and keeps its proportion below that.
struct OperatorBadge: View {
    @Environment(\.colorScheme) private var scheme
    let op: (any OperatorDisplay)?
    var size: BadgeSize = .large

    var body: some View {
        let points = size.points
        let shape = RoundedRectangle(cornerRadius: (Radius.badge * points / BadgeSize.large.points).rounded(), style: .continuous)
        Group {
            if Config.showOperatorLogos, let url = logoURL {
                if let image = LogoStore.shared.image(for: url) {
                    let inset = points * Self.logoInset
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: points - inset * 2, height: points - inset * 2)
                        .clipShape(RoundedRectangle(cornerRadius: (Radius.badge * points / BadgeSize.large.points).rounded() * 0.5, style: .continuous))
                        .frame(width: points, height: points)
                        // The margin in the logo's own colour where its edge is one colour (SJ's green), so no white
                        // frame appears around a logo that has none (owner, 2026-11-17); white for one drawn on clear.
                        .background(Color(uiColor: LogoStore.shared.edgeColor(for: url) ?? .white))
                        .clipShape(shape)
                        .overlay(shape.strokeBorder(Ink.hairline, lineWidth: 1))
                } else {
                    // Initials until the logo is here (it is fetched at launch), never an empty square.
                    initials(shape, points: points).task { await LogoStore.shared.load(url) }
                }
            } else {
                initials(shape, points: points)
            }
        }
        .frame(width: points, height: points)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(op?.name ?? "")
    }

    /// Every logo sits inside the same margin (white, or the logo's edge colour) (designer, 2026-11-07: with a margin on six logos only, the marks
    /// in a departure list came in two sizes and the rows jittered). Before, only the logos that ran to their edges
    /// (Mälartåg, Norrtåg, Öresundståg, Pågatåg, Tågab, X-tåget) had one (owner, 2026-10-25).
    static let logoInset: CGFloat = 0.12

    private var logoURL: URL? {
        guard let path = op?.logoUrl else { return nil }
        return URL(string: Config.apiBase.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path)
    }

    private func initials(_ shape: RoundedRectangle, points: CGFloat) -> some View {
        let label = op?.shortName ?? "?"
        let fontSize = points * (label.count > 2 ? 0.3 : 0.36)
        let known = op.flatMap { Color(hex: $0.brandColor) }
        return Text(label)
            .font(ClackFont.inter(fontSize, .heavy))
            .tracking(fontSize * 0.02)
            .foregroundStyle(known != nil ? Color.white : Ink.bg)
            .shadow(color: known != nil ? Color.black.opacity(0.35) : .clear, radius: 1, y: 1)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: points, height: points)
            .background(known ?? strongColor(scheme), in: shape)
    }
}

/// A journey's operators as their badges, in the order they're ridden, each a little over the next (owner,
/// 2026-11-17: a journey's header had no logo where a train's has one). One badge per operator. A thin gap is cut out
/// of each badge where the one before it sits, so the overlap reads on any background (a card, the tinted hero).
struct OperatorStack: View {
    let operators: [(any OperatorDisplay)?]
    var size: BadgeSize = .small
    /// The most badges shown; a journey with more operators shows the first ones.
    static let limit = 4

    var body: some View {
        let shown = Self.distinct(operators)
        let points = size.points
        let step = points * 0.7
        let gap: CGFloat = 1.5
        let radius = (Radius.badge * points / BadgeSize.large.points).rounded()
        HStack(spacing: step - points) {
            ForEach(Array(shown.enumerated()), id: \.offset) { i, op in
                OperatorBadge(op: op, size: size)
                    .mask {
                        Rectangle()
                            .overlay(alignment: .topLeading) {
                                if i > 0 {
                                    RoundedRectangle(cornerRadius: radius + gap, style: .continuous)
                                        .frame(width: points + gap * 2, height: points + gap * 2)
                                        .offset(x: -step - gap, y: -gap)
                                        .blendMode(.destinationOut)
                                }
                            }
                            .compositingGroup()
                    }
                    .zIndex(Double(shown.count - i))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shown.compactMap { $0?.name }.formatted(.list(type: .and)))
    }

    /// Each operator once, first ridden first; an unknown one once.
    static func distinct(_ operators: [(any OperatorDisplay)?]) -> [(any OperatorDisplay)?] {
        var seen = Set<String>()
        return Array(operators.filter { seen.insert($0?.name ?? "?").inserted }.prefix(limit))
    }
}
