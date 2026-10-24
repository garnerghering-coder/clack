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
/// rounded square in the brand colour with the short name in white (OperatorBadge.tsx). Radius is size × 0.28.
struct OperatorBadge: View {
    let op: (any OperatorDisplay)?
    var size: CGFloat = 36

    var body: some View {
        let radius = (size * 0.28).rounded()
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Group {
            if Config.showOperatorLogos, let url = logoURL {
                if let image = LogoStore.shared.image(for: url) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: size, height: size)
                        .background(.white)
                        .clipShape(shape)
                        .overlay(shape.strokeBorder(Ink.hairline, lineWidth: 1))
                } else {
                    // Initials until the logo is here (it is fetched at launch), never an empty square.
                    initials(shape).task { await LogoStore.shared.load(url) }
                }
            } else {
                initials(shape)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(op?.name ?? "")
    }

    private var logoURL: URL? {
        guard let path = op?.logoUrl else { return nil }
        return URL(string: Config.apiBase.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path)
    }

    private func initials(_ shape: RoundedRectangle) -> some View {
        let label = op?.shortName ?? "?"
        return Text(label)
            .font(ClackFont.inter(size * (label.count > 2 ? 0.3 : 0.36), .heavy))
            .tracking(size * (label.count > 2 ? 0.3 : 0.36) * 0.02)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: size, height: size)
            .background(Color(hex: op?.brandColor) ?? Color(hex: "#3a4555")!, in: shape)
    }
}
