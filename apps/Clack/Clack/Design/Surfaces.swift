//
//  Surfaces.swift
//  Clack
//

import ClackCore
import SwiftUI

/// CSS `linear-gradient(<angle>deg, ...)` over the view's rectangle: 0° points up, 90° right, 180° down, and the
/// gradient line is long enough that the corners get the first and last stop.
struct CSSLinearGradient: View {
    let angle: Double
    let stops: [Gradient.Stop]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let radians = angle * .pi / 180
            let dx = sin(radians)
            let dy = -cos(radians)
            let length = abs(w * dx) + abs(h * dy)
            let start = CGPoint(x: w / 2 - dx * length / 2, y: h / 2 - dy * length / 2)
            let end = CGPoint(x: w / 2 + dx * length / 2, y: h / 2 + dy * length / 2)
            Rectangle().fill(LinearGradient(
                stops: stops,
                startPoint: UnitPoint(x: w > 0 ? start.x / w : 0, y: h > 0 ? start.y / h : 0),
                endPoint: UnitPoint(x: w > 0 ? end.x / w : 1, y: h > 0 ? end.y / h : 1)
            ))
        }
    }
}

/// CSS `radial-gradient(<rx> <ry> at <cx> <cy>, ...)`: an ellipse whose radii are fractions of the width and height,
/// centred at fractions of the size. Stops run from the centre (0) to the radius (1).
struct CSSRadialGradient: View {
    let rx: CGFloat
    let ry: CGFloat
    let cx: CGFloat
    let cy: CGFloat
    let stops: [Gradient.Stop]

    var body: some View {
        Canvas { context, size in
            var ctx = context
            ctx.translateBy(x: cx * size.width, y: cy * size.height)
            ctx.scaleBy(x: max(rx * size.width, 0.001), y: max(ry * size.height, 0.001))
            ctx.fill(
                Path(CGRect(x: -1000, y: -1000, width: 2000, height: 2000)),
                with: .radialGradient(Gradient(stops: stops), center: .zero, startRadius: 0, endRadius: 1)
            )
        }
    }
}

/// The three tinted surfaces of DESIGN_SYSTEM.md §3.10. `op` is the operator colour that tints them (the accent when
/// nothing is tied to an operator).
enum Surface {
    /// a. Cards and board sheets: a quiet lit gradient, tinted 7%.
    struct Lit: View {
        var op: Color = Ink.accent

        var body: some View {
            ZStack {
                CSSLinearGradient(angle: 160, stops: [
                    .init(color: Ink.surfaceRaised, location: 0),
                    .init(color: Ink.surface, location: 0.55),
                    .init(color: Ink.surface, location: 1),
                ])
                CSSRadialGradient(rx: 1.1, ry: 0.7, cx: 1, cy: 0, stops: [
                    .init(color: op.opacity(0.07), location: 0),
                    .init(color: op.opacity(0), location: 0.6),
                ])
            }
        }
    }

    /// b. The hero and the featured trip's body: tinted 30%.
    struct Hero: View {
        var op: Color = Ink.accent

        var body: some View {
            ZStack {
                CSSLinearGradient(angle: 160, stops: [
                    .init(color: Ink.surfaceRaised, location: 0),
                    .init(color: Ink.surface, location: 1),
                ])
                CSSRadialGradient(rx: 1.2, ry: 0.9, cx: 0.85, cy: 0.1, stops: [
                    .init(color: op.opacity(0.30), location: 0),
                    .init(color: op.opacity(0), location: 0.6),
                ])
            }
        }
    }

    /// c. A trip pill: tinted 16% over the plain surface.
    struct Pill: View {
        var op: Color = Ink.accent

        var body: some View {
            ZStack {
                Ink.surface
                CSSRadialGradient(rx: 0.9, ry: 1.2, cx: 1, cy: 0, stops: [
                    .init(color: op.opacity(0.16), location: 0),
                    .init(color: op.opacity(0), location: 0.65),
                ])
            }
        }
    }
}

/// `.card`: padding 14 / 16, radius 16, hairline, the lit surface.
struct Card<Content: View>: View {
    var op: Color = Ink.accent
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Surface.Lit(op: op))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
    }
}

/// `.banner`: a note or a problem, in text on a tinted block (radius 12).
struct Banner<Content: View>: View {
    enum Kind { case neutral, error, warn }

    var kind: Kind = .neutral
    @ViewBuilder var content: Content

    private var background: Color {
        switch kind {
        case .neutral: Ink.surfaceRaised
        case .error: Ink.errorBg
        case .warn: Ink.warnBg
        }
    }

    private var foreground: Color {
        switch kind {
        case .neutral: Ink.text
        case .error: Ink.errorText
        case .warn: Ink.warnText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .clack(.banner)
        .foregroundStyle(foreground)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
    }
}

/// A placeholder row or card while something loads: a soft shimmer from surface to raised and back (1.2 s).
struct Skeleton: View {
    var height: CGFloat = 64
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            // The pattern is two widths long and repeats; it slides right by one pattern per cycle.
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    LinearGradient(
                        colors: [Ink.surface, Ink.surfaceRaised, Ink.surface],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: max(w * 2, 1))
                }
            }
            .offset(x: -w * 2 + phase * w * 2)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 }
        }
    }
}
