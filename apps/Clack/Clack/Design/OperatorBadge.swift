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
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: points, height: points)
                        .background(Color.white)
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
