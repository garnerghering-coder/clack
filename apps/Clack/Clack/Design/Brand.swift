//
//  Brand.swift
//  Clack
//

import SwiftUI

/// The Clack wordmark (owner's design, 2026-10-23): "clack" on five split-flap tiles, each two dark halves with a hinge
/// line, the letter in IBM Plex Mono-style outlines. Drawn from the logo's own units (`WordmarkGlyphs`): the logo is
/// 296 × 84, so a tile is 56 × 84 and one unit is `fontSize × 1.32 / 84`, which keeps the sizes the old wordmark had.
struct Wordmark: View {
    var fontSize: CGFloat = 26
    /// Flip the tiles in one after another (the launch screen).
    var animateIn = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private static let paths: [UIBezierPath] = WordmarkGlyphs.letters.map { SVGLogo.outline($0) ?? UIBezierPath() }
    private static let tileTop = Color(hex: "#171717")!
    private static let tileBottom = Color(hex: "#121212")!
    private static let letter = Color(hex: "#F4F4F0")!

    var body: some View {
        let unit = fontSize * 1.32 / 84
        HStack(spacing: 4 * unit) {
            ForEach(0..<5, id: \.self) { index in
                tile(index, unit: unit)
                    .rotation3DEffect(
                        .degrees(animates && !shown ? -90 : 0), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 1 / 3
                    )
                    .opacity(animates && !shown ? 0 : 1)
                    .animation(.timingCurve(0.3, 0.7, 0.2, 1, duration: 0.42).delay(Double(index) * 0.06), value: shown)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("clack")
        .onAppear { shown = true }
    }

    private var animates: Bool { animateIn && !reduceMotion }

    private func tile(_ index: Int, unit: CGFloat) -> some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: Self.tileTop, location: 0),
                .init(color: Self.tileTop, location: 0.5),
                .init(color: Self.tileBottom, location: 0.5),
                .init(color: Self.tileBottom, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            WordmarkLetter(path: Self.paths[index], originX: CGFloat(60 * index)).fill(Self.letter)
            // The hinge: a thin black line across the middle of the tile.
            Rectangle().fill(Color.black).frame(height: unit)
        }
        .frame(width: 56 * unit, height: 84 * unit)
        .clipShape(RoundedRectangle(cornerRadius: 10 * unit, style: .continuous))
    }
}

/// One letter of the wordmark, scaled from the logo's units to the tile it sits in.
private struct WordmarkLetter: Shape {
    let path: UIBezierPath
    /// Where this letter's tile starts in the logo (the letters are drawn at their place along it).
    let originX: CGFloat

    func path(in rect: CGRect) -> Path {
        let k = rect.width / 56
        return Path(path.cgPath).applying(CGAffineTransform(scaleX: k, y: k).translatedBy(x: -originX, y: 0))
    }
}

/// The launch screen: the wordmark flipping in on signal yellow (#FFD400), nothing else. Shown until the settings have
/// loaded and at least 900 ms have passed, then it fades out over 350 ms.
struct Splash: View {
    var body: some View {
        ZStack {
            Color(hex: "#FFD400")!
            Wordmark(fontSize: 64, animateIn: true)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .accessibilityHidden(true)
    }
}
