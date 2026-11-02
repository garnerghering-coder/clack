//
//  TicketReaderDumpTests.swift
//  ClackTests
//
//  Not a test: a tool for adding ticket layouts. Run with the ticket files' paths, comma-separated:
//      TICKET_DUMP="$HOME/Downloads/a.pdf,$HOME/Downloads/b.eml" swift test --filter TicketReaderDumpTests
//  It prints each page's text as PDFKit reads it (as a Swift literal, to cut down into a fixture with every name and
//  number replaced), what TicketReader makes of it, and the barcodes found. It writes nothing, and the files are never
//  committed.
//

import Foundation
import Testing
@testable import ClackCore
#if canImport(Vision)
import Vision
#endif

struct TicketReaderDumpTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["TICKET_DUMP"] != nil))
    func dump() throws {
        let paths = (ProcessInfo.processInfo.environment["TICKET_DUMP"] ?? "").split(separator: ",").map(String.init)
        for path in paths {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            let pdf = url.pathExtension.lowercased() == "eml" ? TicketReader.pdf(fromEmail: data) : data
            print("===== \(url.lastPathComponent)")
            guard let pdf else { print("no PDF"); continue }
            for (i, page) in TicketReader.pdfPages(pdf).enumerated() {
                let literal = page.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\u{FFFC}", with: "\\u{FFFC}")
                print("--- page \(i)\n\"\(literal)\"")
            }
            print("--- trains")
            for (train, page) in TicketReader.located(fromPages: TicketReader.pdfPages(pdf)) { print("p\(page) \(train)") }
            print("--- barcodes")
            for code in TicketBarcode.find(inPDF: pdf) {
                let head = code.payload.prefix(12)
                let ascii = String(head.map { (32..<127).contains($0) ? Character(UnicodeScalar($0)) : "." })
                print("p\(code.page) \(code.format) \(code.payload.count) bytes, starts \(head.map { String(format: "%02x", $0) }.joined()) \"\(ascii)\"")
            }
            #if canImport(Vision)
            // Every kind of code on each page, read or not.
            for (i, image) in TicketBarcode.pageImages(pdf).enumerated() {
                let request = VNDetectBarcodesRequest()
                try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
                print("p\(i) codes: \((request.results ?? []).map(\.symbology.rawValue))")
            }
            #endif
        }
    }
}
