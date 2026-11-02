//
//  TicketBarcodeTests.swift
//  ClackTests
//
//  A copied ticket code is only any use if it carries the same bytes, so these make Aztec codes with Core Image from
//  known bytes (binary, text, and both mixed) and read them back.
//

import Foundation
import Testing
@testable import ClackCore
#if canImport(CoreImage) && canImport(Vision)
import CoreImage

struct TicketBarcodeTests {
    /// Vision reads the full-range Aztec symbols tickets use (and, in this test setup, not the compact ones Core Image
    /// picks for short messages), so the codes are made full-range.
    private func roundTrip(_ message: Data) -> Data? {
        let filter = CIFilter(name: "CIAztecCodeGenerator")!
        filter.setValue(message, forKey: "inputMessage")
        filter.setValue(0, forKey: "inputCompactStyle")
        let code = filter.outputImage!.samplingNearest().transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let image = code.composited(over: CIImage(color: .white).cropped(to: code.extent.insetBy(dx: -48, dy: -48)))
        guard let cg = CIContext().createCGImage(image, from: image.extent) else { return nil }
        return TicketBarcode.find(in: cg).first?.payload
    }

    @Test func everyByteValueComesBack() {
        let message = Data((0...255).map { UInt8($0) } + (0...255).reversed().map { UInt8($0) })
        #expect(roundTrip(message) == message)
    }

    @Test func aUICStyleMessageComesBack() {
        // "#UT01" and a company code as text, then compressed-looking bytes.
        var message = Data("#UT011080000010".utf8)
        message += Data((0..<300).map { UInt8(($0 * 37 + 11) % 256) })
        #expect(roundTrip(message) == message)
    }

    @Test func plainTextComesBack() {
        let message = Data("Kolding St. -> Kobenhavn H, tog 394. Vogn 10, plads 32: ok!".utf8)
        #expect(roundTrip(message) == message)
    }

    @Test func aShortBinaryRunReads() {
        // B/S, a 5-bit length of 2, then 0xFF 0x00.
        var bits = "11111" + "00010" + "11111111" + "00000000"
        while bits.count % 8 != 0 { bits += "1" }
        let bytes = stride(from: 0, to: bits.count, by: 8).map { i -> UInt8 in
            UInt8(bits[bits.index(bits.startIndex, offsetBy: i)..<bits.index(bits.startIndex, offsetBy: i + 8)], radix: 2)!
        }
        #expect(TicketBarcode.aztecMessage(fromBitstream: Data(bytes)) == Data([0xFF, 0x00]))
    }
}
#endif
