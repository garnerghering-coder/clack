//
//  SVGLogo.swift
//  Clack
//

import ClackCore
import UIKit

/// Draws the simple SVG logos some operators publish, since `UIImage` can't read SVG: filled outlines (`<path d fill>`) and
/// a picture embedded in the SVG (`<image href="data:...">`). Anything else (arcs, gradients, transforms) returns nil, and
/// the badge keeps the operator's initials.
nonisolated enum SVGLogo {
    static func image(from data: Data, size: CGFloat = 256) -> UIImage? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        if let embedded = embeddedImage(in: text) { return embedded }
        let box = viewBox(in: text)
        let paths = elements(named: "path", in: text)
        guard !paths.isEmpty, box.width > 0, box.height > 0 else { return nil }
        var drawn: [(UIBezierPath, UIColor)] = []
        for attributes in paths {
            let fill = attributes["fill"] ?? "#000000"
            if fill == "none" { continue }
            guard let d = attributes["d"], let path = outline(d), let color = color(fill) else { return nil }
            drawn.append((path, color))
        }
        guard !drawn.isEmpty else { return nil }
        let scale = min(size / box.width, size / box.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { _ in
            let transform = CGAffineTransform(translationX: (size - box.width * scale) / 2 - box.minX * scale, y: (size - box.height * scale) / 2 - box.minY * scale)
                .scaledBy(x: scale, y: scale)
            for (path, color) in drawn {
                let copy = UIBezierPath(cgPath: path.cgPath)
                copy.apply(transform)
                color.setFill()
                copy.fill()
            }
        }
    }

    // MARK: reading the file

    private static func viewBox(in text: String) -> CGRect {
        guard let value = attribute("viewBox", in: text) else { return .zero }
        let n = value.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        return n.count == 4 ? CGRect(x: n[0], y: n[1], width: n[2], height: n[3]) : .zero
    }

    private static func attribute(_ name: String, in text: String) -> String? {
        guard let range = text.range(of: "\\b\(name)=\"([^\"]*)\"", options: .regularExpression) else { return nil }
        let match = String(text[range])
        return String(match.dropFirst(name.count + 2).dropLast())
    }

    /// The attributes of each `<name ...>` element.
    private static func elements(named name: String, in text: String) -> [[String: String]] {
        guard let regex = try? NSRegularExpression(pattern: "<\(name)\\b([^>]*)>") else { return [] }
        let whole = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: whole).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            let body = String(text[range])
            var out: [String: String] = [:]
            guard let pair = try? NSRegularExpression(pattern: "([\\w:-]+)=\"([^\"]*)\"") else { return out }
            for m in pair.matches(in: body, range: NSRange(body.startIndex..., in: body)) {
                if let k = Range(m.range(at: 1), in: body), let v = Range(m.range(at: 2), in: body) { out[String(body[k])] = String(body[v]) }
            }
            return out
        }
    }

    private static func embeddedImage(in text: String) -> UIImage? {
        for attributes in elements(named: "image", in: text) {
            let href = attributes["href"] ?? attributes["xlink:href"] ?? ""
            guard let comma = href.firstIndex(of: ","), href.hasPrefix("data:image/"), href[..<comma].contains("base64") else { continue }
            let encoded = String(href[href.index(after: comma)...]).filter { !$0.isWhitespace }
            if let data = Data(base64Encoded: encoded), let image = UIImage(data: data) { return image }
        }
        return nil
    }

    private static func color(_ text: String) -> UIColor? {
        var hex = text.trimmingCharacters(in: .whitespaces)
        guard hex.hasPrefix("#") else { return text == "black" ? .black : text == "white" ? .white : nil }
        hex.removeFirst()
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard hex.count == 6, let n = Int(hex, radix: 16) else { return nil }
        return UIColor(red: CGFloat((n >> 16) & 255) / 255, green: CGFloat((n >> 8) & 255) / 255, blue: CGFloat(n & 255) / 255, alpha: 1)
    }

    // MARK: path data

    /// A path from SVG path data: M L H V C S Q T Z, absolute or relative. Arcs aren't drawn (nil).
    static func outline(_ d: String) -> UIBezierPath? {
        guard let regex = try? NSRegularExpression(pattern: "[MmLlHhVvCcSsQqTtAaZz]|-?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][-+]?\\d+)?") else { return nil }
        let tokens = regex.matches(in: d, range: NSRange(d.startIndex..., in: d)).compactMap { Range($0.range, in: d).map { String(d[$0]) } }
        let path = UIBezierPath()
        var i = 0
        var command: Character = "M"
        var current = CGPoint.zero, start = CGPoint.zero
        var lastControl: CGPoint?
        func number() -> Double? {
            guard i < tokens.count, let v = Double(tokens[i]) else { return nil }
            i += 1
            return v
        }
        func point(_ relative: Bool) -> CGPoint? {
            guard let x = number(), let y = number() else { return nil }
            return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        }
        while i < tokens.count {
            if let first = tokens[i].first, first.isLetter {
                command = first
                i += 1
                if command == "Z" || command == "z" {
                    path.close()
                    current = start
                    lastControl = nil
                    continue
                }
            }
            let relative = command.isLowercase
            switch command.uppercased() {
            case "M":
                guard let p = point(relative) else { return nil }
                path.move(to: p); current = p; start = p; lastControl = nil
                command = relative ? "l" : "L"
            case "L":
                guard let p = point(relative) else { return nil }
                path.addLine(to: p); current = p; lastControl = nil
            case "H":
                guard let x = number() else { return nil }
                current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                path.addLine(to: current); lastControl = nil
            case "V":
                guard let y = number() else { return nil }
                current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                path.addLine(to: current); lastControl = nil
            case "C":
                guard let c1 = point(relative), let c2 = point(relative), let p = point(relative) else { return nil }
                path.addCurve(to: p, controlPoint1: c1, controlPoint2: c2); current = p; lastControl = c2
            case "S":
                let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                guard let c2 = point(relative), let p = point(relative) else { return nil }
                path.addCurve(to: p, controlPoint1: c1, controlPoint2: c2); current = p; lastControl = c2
            case "Q":
                guard let c = point(relative), let p = point(relative) else { return nil }
                path.addQuadCurve(to: p, controlPoint: c); current = p; lastControl = c
            case "T":
                let c = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                guard let p = point(relative) else { return nil }
                path.addQuadCurve(to: p, controlPoint: c); current = p; lastControl = c
            default:
                return nil
            }
        }
        return path
    }
}
