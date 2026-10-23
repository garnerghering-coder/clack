//
//  Brand.swift
//  Clack
//

import SwiftUI

/// The Clack wordmark (owner's design, 2026-10-21): "clack" on split-flap tiles, the last one signal yellow.
/// Sizes are in em of `fontSize`, as in the CSS: a tile is 0.92 × 1.32 em with radius 0.16 em.
struct Wordmark: View {
    var fontSize: CGFloat = 26
    var rule = false
    /// Flip the tiles in one after another (the launch screen).
    var animateIn = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private let letters = ["c", "l", "a", "c", "k"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: fontSize * 0.1) {
                ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                    tile(letter, accent: index == 4)
                        .rotation3DEffect(
                            .degrees(animates && !shown ? -90 : 0), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 1 / 3
                        )
                        .opacity(animates && !shown ? 0 : 1)
                        .animation(.timingCurve(0.3, 0.7, 0.2, 1, duration: 0.42).delay(Double(index) * 0.06), value: shown)
                }
            }
            if rule {
                RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
                    .fill(Ink.accentInk)
                    .frame(height: fontSize * 0.12)
                    .padding(.top, fontSize * 0.4)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("clack")
        .onAppear { shown = true }
    }

    private var animates: Bool { animateIn && !reduceMotion }

    private func tile(_ letter: String, accent: Bool) -> some View {
        let w = fontSize * 0.92
        let h = fontSize * 1.32
        let top = accent ? Color(hex: "#f8d64a")! : Ink.flapTop
        let bottom = accent ? Color(hex: "#e9c63c")! : Ink.flapBottom
        return ZStack {
            LinearGradient(stops: [
                .init(color: top, location: 0),
                .init(color: top, location: 0.495),
                .init(color: bottom, location: 0.505),
                .init(color: bottom, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            Text(letter)
                .font(ClackFont.inter(fontSize, .heavy))
                .foregroundStyle(accent ? Color(hex: "#0a0a0a")! : Ink.flapText)
                .frame(width: w, height: h)
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: fontSize * 0.16, style: .continuous))
        .overlay {
            // The hinge: a thin line across the tile with a small pin sticking out each side.
            Rectangle()
                .fill(accent ? Color.black.opacity(0.35) : Ink.flapHinge)
                .frame(width: w + fontSize * 0.12, height: fontSize * 0.05)
        }
    }
}

/// The launch screen: the wordmark, a yellow rule, the tagline. Shown until the settings have loaded and at least
/// 900 ms have passed, then it fades out over 350 ms.
struct Splash: View {
    @Environment(L10n.self) private var l10n

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Ink.bg
                Wordmark(fontSize: 64, rule: true, animateIn: true)
                Text(l10n.t("app.tagline"))
                    .clack(.splashTagline)
                    .foregroundStyle(Ink.text2)
                    .frame(maxWidth: .infinity)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.82)
            }
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }
}
