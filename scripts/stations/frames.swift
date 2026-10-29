// Frames from a station walking-tour video, for reading signs, stairs, lifts and platform numbers off
// (docs/STATION_MAPPING.md; docs/buildout/BUILDOUT.md "Station videos"). No ffmpeg on this Mac, so AVFoundation.
//
//   swift scripts/stations/frames.swift <video> [--out <dir>] [--every 2] [--width 1280] [--scene 0.18] [--info]
//
// - one JPEG every `every` seconds, 1280 px wide, named by its time (frame_0012-00.jpg = 12 s);
// - when the picture changes a lot between two of those (a turn, a doorway: mean grey difference over a 32×18
//   thumbnail above `scene`), the three frames in between (+0.5, +1.0, +1.5 s) are written too, marked "scene";
// - `--info` only prints duration and size as one JSON line (for INDEX.md).
// Output goes to <video's folder>/frames/ by default, outside the repo: frames are never committed or shipped.
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Options {
    var video = ""
    var out: String?
    var every = 2.0
    var width = 1280
    var scene = 0.18
    var infoOnly = false
}

func parse(_ args: [String]) -> Options {
    var o = Options()
    var i = 0
    while i < args.count {
        let a = args[i]
        func value() -> String { i += 1; return i < args.count ? args[i] : "" }
        switch a {
        case "--out": o.out = value()
        case "--every": o.every = Double(value()) ?? o.every
        case "--width": o.width = Int(value()) ?? o.width
        case "--scene": o.scene = Double(value()) ?? o.scene
        case "--info": o.infoOnly = true
        default: if o.video.isEmpty { o.video = a }
        }
        i += 1
    }
    return o
}

let opts = parse(Array(CommandLine.arguments.dropFirst()))
guard !opts.video.isEmpty else {
    FileHandle.standardError.write("usage: frames.swift <video> [--out dir] [--every 2] [--width 1280] [--scene 0.18] [--info]\n".data(using: .utf8)!)
    exit(2)
}
let url = URL(fileURLWithPath: opts.video)
let asset = AVURLAsset(url: url)
let duration = CMTimeGetSeconds(asset.duration)
let track = asset.tracks(withMediaType: .video).first
let size = track.map { $0.naturalSize.applying($0.preferredTransform) } ?? .zero
let fps = track?.nominalFrameRate ?? 0
let info: [String: Any] = ["file": url.lastPathComponent, "durationS": Int(duration.rounded()), "width": Int(abs(size.width)), "height": Int(abs(size.height)), "fps": Double(Int(fps * 100)) / 100]
let infoJson = try! JSONSerialization.data(withJSONObject: info, options: [.sortedKeys])
print(String(data: infoJson, encoding: .utf8)!)
if opts.infoOnly { exit(0) }

let outDir = URL(fileURLWithPath: opts.out ?? url.deletingLastPathComponent().appendingPathComponent("frames").path)
try! FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.maximumSize = CGSize(width: opts.width, height: opts.width)
// Half a second of tolerance keeps it from decoding from the last keyframe for every frame.
gen.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
gen.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)

func thumb(_ img: CGImage) -> [Float] {
    let w = 32, h = 18
    var buf = [UInt8](repeating: 0, count: w * h)
    let cs = CGColorSpaceCreateDeviceGray()
    guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return [] }
    ctx.interpolationQuality = .low
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return buf.map { Float($0) / 255 }
}

func difference(_ a: [Float], _ b: [Float]) -> Float {
    guard a.count == b.count, !a.isEmpty else { return 1 }
    var s: Float = 0
    for i in 0..<a.count { s += abs(a[i] - b[i]) }
    return s / Float(a.count)
}

func name(_ t: Double) -> String {
    let whole = Int(t)
    let frac = Int(((t - Double(whole)) * 100).rounded())
    return String(format: "frame_%04d-%02d.jpg", whole, frac)
}

func write(_ img: CGImage, at t: Double) -> String {
    let file = outDir.appendingPathComponent(name(t))
    guard let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return file.lastPathComponent }
    CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    CGImageDestinationFinalize(dest)
    return file.lastPathComponent
}

func grab(_ t: Double) -> CGImage? {
    var actual = CMTime.zero
    return try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: &actual)
}

var index: [[String: Any]] = []
var previous: [Float] = []
var t = 0.0
var scenes = 0
while t < duration {
    guard let img = grab(t) else { t += opts.every; continue }
    let th = thumb(img)
    let diff = previous.isEmpty ? 0 : difference(previous, th)
    if diff > Float(opts.scene) {
        // Fill in the gap before this frame.
        scenes += 1
        for k in 1...3 {
            let tt = t - opts.every + Double(k) * opts.every / 4
            if tt > 0, let extra = grab(tt) { index.append(["t": tt, "file": write(extra, at: tt), "scene": true]) }
        }
    }
    index.append(["t": t, "file": write(img, at: t), "scene": diff > Float(opts.scene)])
    previous = th
    t += opts.every
    if Int(t) % 120 == 0 { FileHandle.standardError.write("\(Int(t))/\(Int(duration)) s, \(index.count) frames\n".data(using: .utf8)!) }
}
let indexFile = outDir.appendingPathComponent("index.json")
let payload: [String: Any] = ["video": url.lastPathComponent, "durationS": Int(duration.rounded()), "everyS": opts.every, "sceneThreshold": opts.scene, "frames": index]
try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]).write(to: indexFile)
print("wrote \(index.count) frames (\(scenes) scene changes) to \(outDir.path)")
