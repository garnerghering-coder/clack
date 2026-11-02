//
//  TicketBarcode.swift
//  Clack
//

import Foundation
#if canImport(Vision) && canImport(CoreGraphics) && canImport(CoreImage)
import CoreGraphics
import CoreImage
import Vision
#endif

/// The machine-readable code on a ticket page: what a conductor's scanner reads. Kept as the exact bytes Vision
/// decoded (a UIC ticket's code is binary, compressed and signed), so a copy of it scans the same. Nothing in it is
/// read or shown by Clack.
public nonisolated struct TicketBarcode: Hashable, Sendable, Codable {
    public enum Format: String, Hashable, Sendable, Codable { case aztec }

    public var format: Format
    public var payload: Data
    /// The PDF page (0-based) the code is on.
    public var page: Int

    public init(format: Format, payload: Data, page: Int) {
        self.format = format
        self.payload = payload
        self.page = page
    }
}

extension TicketBarcode {
    /// The Aztec codes on a PDF's pages, in page order. Each page is drawn at about 2400 px on its short side, which reads
    /// the dense Aztec codes on DSB and DB tickets.
    public static func find(inPDF data: Data) -> [TicketBarcode] {
        #if canImport(Vision) && canImport(CoreGraphics) && canImport(CoreImage)
        guard let provider = CGDataProvider(data: data as CFData), let doc = CGPDFDocument(provider) else { return [] }
        var out: [TicketBarcode] = []
        for index in 0..<doc.numberOfPages {
            // CGPDFDocument pages are 1-based.
            guard let page = doc.page(at: index + 1), let image = render(page) else { continue }
            out += find(in: image).map { TicketBarcode(format: $0.format, payload: $0.payload, page: index) }
        }
        return out
        #else
        return []
        #endif
    }

    // MARK: Aztec bitstream

    /// Vision's `payloadData` for an Aztec code is the symbol's data codewords as read off it, not the message: a DB
    /// ticket's starts with the bits for P/S "#", "U", "T" (UIC 918.3's "#UT"). Two steps turn it back into the
    /// message, both from the Aztec specification (ISO/IEC 24778): undo the bit stuffing (a codeword whose first
    /// b-1 bits are all equal has one extra, opposite bit at the end: drop it), then read the high-level encoding (the
    /// Upper, Lower, Mixed, Punct and Digit tables, with 5-bit codes and 4-bit digits, and Binary Shift runs). ECI
    /// flags are skipped and FNC1 gives GS (0x1D). The codeword size follows from the symbol's layers: 6 bits for 1-2
    /// layers, 8 for 3-8, 10 for 9-22, 12 above. Nil when the codewords or the bits don't make sense.
    public static func aztecMessage(fromCodewords data: Data, layers: Int) -> Data? {
        let size = layers <= 2 ? 6 : layers <= 8 ? 8 : layers <= 22 ? 10 : 12
        let raw: [Bool] = [UInt8](data).flatMap { byte in (0..<8).map { byte >> (7 - $0) & 1 == 1 } }
        var bits: [Bool] = []
        var at = 0
        while at + size <= raw.count {
            let word = raw[at..<(at + size)]
            let head = word.dropLast()
            if head.allSatisfy({ $0 == head.first }) {
                // All b bits equal is not a valid codeword; past the data it is padding, so stop there.
                guard word.last != head.first else { break }
                bits.append(contentsOf: head)
            } else {
                bits.append(contentsOf: word)
            }
            at += size
        }
        return aztecMessage(fromBits: bits)
    }

    /// The message in an unstuffed Aztec bitstream (see `aztecMessage(fromCodewords:layers:)`).
    static func aztecMessage(fromBitstream data: Data) -> Data? {
        aztecMessage(fromBits: [UInt8](data).flatMap { byte in (0..<8).map { byte >> (7 - $0) & 1 == 1 } })
    }

    private static func aztecMessage(fromBits bits: [Bool]) -> Data? {
        enum Mode: Character { case upper = "U", lower = "L", mixed = "M", punct = "P", digit = "D", binary = "B" }
        let upper = ["CTRL_PS", " "] + (65...90).map { String(UnicodeScalar(UInt8($0))) } + ["CTRL_LL", "CTRL_ML", "CTRL_DL", "CTRL_BS"]
        let lower = ["CTRL_PS", " "] + (97...122).map { String(UnicodeScalar(UInt8($0))) } + ["CTRL_US", "CTRL_ML", "CTRL_DL", "CTRL_BS"]
        let mixed = ["CTRL_PS", " "] + ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 27, 28, 29, 30, 31, 64, 92, 94, 95, 96, 124, 126, 127] as [UInt8]).map { String(UnicodeScalar($0)) }
            + ["CTRL_LL", "CTRL_UL", "CTRL_PL", "CTRL_BS"]
        let punct = ["FLG(n)", "\r", "\r\n", ". ", ", ", ": ", "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/", ":", ";", "<", "=", ">", "?", "[", "]", "{", "}", "CTRL_UL"]
        let digit = ["CTRL_PS", " "] + (0...9).map(String.init) + [",", ".", "CTRL_UL", "CTRL_US"]
        func table(_ mode: Mode) -> [String] {
            switch mode {
            case .upper: upper
            case .lower: lower
            case .mixed: mixed
            case .punct: punct
            case .digit: digit
            case .binary: []
            }
        }

        let end = bits.count
        var at = 0
        func read(_ n: Int) -> Int {
            var value = 0
            for _ in 0..<n {
                value = value << 1 | (bits[at] ? 1 : 0)
                at += 1
            }
            return value
        }

        var out: [UInt8] = []
        var latch = Mode.upper, shift = Mode.upper
        while at < end {
            if shift == .binary {
                guard end - at >= 5 else { break }
                var length = read(5)
                if length == 0 {
                    guard end - at >= 11 else { break }
                    length = read(11) + 31
                }
                guard end - at >= length * 8 else { return nil }
                for _ in 0..<length { out.append(UInt8(read(8))) }
                shift = latch
                continue
            }
            let size = shift == .digit ? 4 : 5
            guard end - at >= size else { break }
            let word = table(shift)[read(size)]
            if word == "FLG(n)" {
                guard end - at >= 3 else { break }
                let n = read(3)
                if n == 0 {
                    out.append(0x1D)
                } else if n == 7 {
                    return nil
                } else {
                    guard end - at >= 4 * n else { break }
                    _ = read(4 * n)
                }
                shift = latch
            } else if word.hasPrefix("CTRL_") {
                let chars = Array(word)
                latch = shift
                guard let next = Mode(rawValue: chars[5]) else { return nil }
                shift = next
                if chars[6] == "L" { latch = shift }
            } else {
                out += Array(word.utf8)
                shift = latch
            }
        }
        return Data(out)
    }

    #if canImport(Vision) && canImport(CoreGraphics) && canImport(CoreImage)
    /// The Aztec codes in an image, as message bytes. Only Aztec for now: it is what the DSB, DB and SJ tickets
    /// carry, and Vision's QR and PDF417 payloads would each need their own bitstream decoding, checked the same way.
    public static func find(in image: CGImage) -> [(format: Format, payload: Data)] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.aztec]
        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        } catch {
            return []
        }
        return (request.results ?? []).compactMap { observation in
            guard observation.symbology == .aztec, let codewords = observation.payloadData,
                  let descriptor = observation.barcodeDescriptor as? CIAztecCodeDescriptor,
                  let message = aztecMessage(fromCodewords: codewords, layers: descriptor.layerCount), !message.isEmpty else { return nil }
            return (.aztec, message)
        }
    }

    /// Each page of a PDF as an image (for the dump tool's look at codes Clack doesn't read yet).
    static func pageImages(_ data: Data) -> [CGImage] {
        guard let provider = CGDataProvider(data: data as CFData), let doc = CGPDFDocument(provider) else { return [] }
        return (0..<doc.numberOfPages).compactMap { doc.page(at: $0 + 1).flatMap(render) }
    }

    private static func render(_ page: CGPDFPage) -> CGImage? {
        let box = page.getBoxRect(.mediaBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let scale = 2400 / min(box.width, box.height)
        let width = Int(box.width * scale), height = Int(box.height * scale)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .none
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.drawPDFPage(page)
        return context.makeImage()
    }
    #endif
}
