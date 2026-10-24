//
//  SVGLogoTests.swift
//  ClackTests
//

import Foundation
import Testing
import UIKit
@testable import Clack
@testable import ClackCore

struct SVGLogoTests {
    /// Mälartåg's own logo file: two filled outlines.
    private let malartag = #"""
<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M2.55693 7.39233C1.87929 7.39233 1.23045 7.66394 0.750344 8.14405C0.270233 8.62416 0 9.27437 0 9.95338C0 10.6324 0.270233 11.2826 0.750344 11.7627C1.23045 12.2428 1.87929 12.5144 2.55693 12.5144C3.23457 12.5144 3.88341 12.2428 4.36352 11.7627C4.84363 11.2826 5.11386 10.6324 5.11386 9.95338C5.11386 9.27437 4.84363 8.62416 4.36352 8.14405C3.8889 7.66394 3.23457 7.39233 2.55693 7.39233Z" fill="#00204C"/>
<path d="M13.4485 7.39233H10.8134C10.4636 7.39233 10.1303 7.25104 9.88747 7.00824C9.63919 6.75995 9.50338 6.42525 9.50338 6.08094V5.56653C9.50338 4.88752 9.23315 4.23183 8.75304 3.7572C8.26744 3.27161 7.61861 3 6.94097 3C6.26332 3 5.609 3.27161 5.13438 3.75172C4.65427 4.23183 4.38403 4.88203 4.38403 5.56105C4.38403 6.24006 4.65427 6.89027 5.13438 7.37038C5.61449 7.85049 6.26332 8.12209 6.94097 8.12209H7.454C7.80379 8.12209 8.13713 8.2579 8.37992 8.50618C8.62821 8.75447 8.76401 9.08917 8.76401 9.43348V9.94789C8.76401 10.6269 9.03425 11.2771 9.51436 11.7572C9.99447 12.2373 10.6433 12.5089 11.3209 12.5089H13.443C14.1207 12.5089 14.7695 12.2373 15.2496 11.7572C15.7297 11.2771 16 10.6269 16 9.94789C16 9.26887 15.7284 8.61867 15.2496 8.13856C14.775 7.66393 14.1262 7.39233 13.4499 7.39233H13.4485Z" fill="#00204C"/>
</svg>
"""#

    private func opaquePixels(_ image: UIImage) -> Int {
        guard let cg = image.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return 0 }
        var count = 0
        for i in stride(from: 3, to: CFDataGetLength(data), by: 4) where bytes[i] > 128 { count += 1 }
        return count
    }

    @Test func drawsTheFilledOutlinesOfASimpleLogo() throws {
        let image = try #require(SVGLogo.image(from: Data(malartag.utf8)))
        #expect(image.size.width == 256)
        // Something is drawn, and not the whole square.
        let drawn = opaquePixels(image)
        #expect(drawn > 3_000)
        #expect(drawn < 256 * 256 * 3 / 4)
    }

    @Test func usesAPictureEmbeddedInTheSVG() throws {
        let png = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }.pngData()!
        let svg = "<svg viewBox=\"0 0 4 4\"><image width=\"4\" height=\"4\" href=\"data:image/png;base64,\(png.base64EncodedString())\"/></svg>"
        let image = try #require(SVGLogo.image(from: Data(svg.utf8)))
        #expect(image.size.width > 0)
    }

    @Test func givesUpOnWhatItCannotDraw() {
        let arcs = ##"<svg viewBox="0 0 10 10"><path d="M0 0 A5 5 0 0 1 10 10" fill="#000"/></svg>"##
        #expect(SVGLogo.image(from: Data(arcs.utf8)) == nil)
        #expect(SVGLogo.image(from: Data("not an svg".utf8)) == nil)
    }

    @Test func readsRelativeCommandsAndNumbersWithoutSeparators() throws {
        let path = try #require(SVGLogo.outline("m1 1l2 0 0 2-2 0z"))
        #expect(path.bounds == CGRect(x: 1, y: 1, width: 2, height: 2))
    }
}
