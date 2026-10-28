//
//  WalkLog.swift
//  ClackCore
//

import Foundation

/// One walk recorded with the station test tools (owner only, TestFlight): every sensor the phone offers, with
/// timestamps, plus the routes, marks and notes the walker adds. It is the raw material for the station work (the
/// walking model, the maps, the indoor dot), so nothing is summarised away here. Times are seconds since 1970.
public nonisolated struct WalkLog: Codable, Hashable, Sendable, Identifiable {
    public static let formatVersion = 1

    public var version = WalkLog.formatVersion
    public var id: String
    public var title: String
    public var startedAt: Double
    public var endedAt: Double?
    public var device: Device
    public var routes: [Route] = []
    /// The suggested routes ticked off (their names).
    public var checklist: [String] = []
    public var note: String = ""

    public var location: [Location] = []
    public var heading: [Heading] = []
    public var pressure: [Pressure] = []
    public var absoluteAltitude: [AbsoluteAltitude] = []
    public var motion: [Motion] = []
    public var steps: [Steps] = []
    public var stepEvents: [StepEvent] = []
    public var activity: [Activity] = []
    public var ar: [ARPose] = []
    /// When AR mode was switched on and off, and why tracking was limited.
    public var events: [Event] = []

    public init(id: String = UUID().uuidString, title: String, startedAt: Double, device: Device) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.device = device
    }

    public struct Device: Codable, Hashable, Sendable {
        public var model: String
        public var system: String
        public var appBuild: String
        public init(model: String, system: String, appBuild: String) {
            self.model = model
            self.system = system
            self.appBuild = appBuild
        }
    }

    /// A stretch the walker names ("Platform 2 → main exit, with suitcase"), with marks along it.
    public struct Route: Codable, Hashable, Sendable, Identifiable {
        public var id: String
        public var name: String
        public var startedAt: Double
        public var endedAt: Double?
        public var note: String = ""
        public var marks: [Mark] = []
        public init(id: String = UUID().uuidString, name: String, startedAt: Double) {
            self.id = id
            self.name = name
            self.startedAt = startedAt
        }
    }

    /// A landmark the walker passed ("bottom of the stairs to platform 2"), with where the phone thought it was.
    public struct Mark: Codable, Hashable, Sendable, Identifiable {
        public var id: String
        public var t: Double
        public var label: String
        public var lat: Double?
        public var lon: Double?
        public var hAcc: Double?
        public var relAlt: Double?
        public init(id: String = UUID().uuidString, t: Double, label: String, lat: Double? = nil, lon: Double? = nil, hAcc: Double? = nil, relAlt: Double? = nil) {
            self.id = id
            self.t = t
            self.label = label
            self.lat = lat
            self.lon = lon
            self.hAcc = hAcc
            self.relAlt = relAlt
        }
    }

    public struct Location: Codable, Hashable, Sendable {
        public var t: Double
        public var lat: Double
        public var lon: Double
        public var alt: Double
        public var hAcc: Double
        public var vAcc: Double
        public var speed: Double
        public var speedAcc: Double
        public var course: Double
        public var courseAcc: Double
        /// The building level iOS reports, where it knows one.
        public var floor: Int?
        public var simulated: Bool
        public var accessory: Bool
        public init(t: Double, lat: Double, lon: Double, alt: Double, hAcc: Double, vAcc: Double, speed: Double, speedAcc: Double, course: Double, courseAcc: Double, floor: Int?, simulated: Bool, accessory: Bool) {
            self.t = t; self.lat = lat; self.lon = lon; self.alt = alt; self.hAcc = hAcc; self.vAcc = vAcc
            self.speed = speed; self.speedAcc = speedAcc; self.course = course; self.courseAcc = courseAcc
            self.floor = floor; self.simulated = simulated; self.accessory = accessory
        }
    }

    public struct Heading: Codable, Hashable, Sendable {
        public var t: Double
        public var magnetic: Double
        public var trueHeading: Double
        public var accuracy: Double
        public init(t: Double, magnetic: Double, trueHeading: Double, accuracy: Double) {
            self.t = t; self.magnetic = magnetic; self.trueHeading = trueHeading; self.accuracy = accuracy
        }
    }

    /// Barometer: change in height since the walk started (m) and air pressure (kPa).
    public struct Pressure: Codable, Hashable, Sendable {
        public var t: Double
        public var relAlt: Double
        public var kPa: Double
        public init(t: Double, relAlt: Double, kPa: Double) { self.t = t; self.relAlt = relAlt; self.kPa = kPa }
    }

    public struct AbsoluteAltitude: Codable, Hashable, Sendable {
        public var t: Double
        public var alt: Double
        public var accuracy: Double
        public var precision: Double
        public init(t: Double, alt: Double, accuracy: Double, precision: Double) {
            self.t = t; self.alt = alt; self.accuracy = accuracy; self.precision = precision
        }
    }

    /// Device motion at ~50 Hz: attitude quaternion, rotation rate (rad/s), user acceleration and gravity (g),
    /// calibrated magnetic field (µT) and its accuracy (−1 uncalibrated … 2 high).
    public struct Motion: Codable, Hashable, Sendable {
        public var t: Double
        public var q: [Double]
        public var rot: [Double]
        public var acc: [Double]
        public var grav: [Double]
        public var mag: [Double]
        public var magAcc: Int
        public init(t: Double, q: [Double], rot: [Double], acc: [Double], grav: [Double], mag: [Double], magAcc: Int) {
            self.t = t; self.q = q; self.rot = rot; self.acc = acc; self.grav = grav; self.mag = mag; self.magAcc = magAcc
        }
    }

    /// Cumulative pedometer values since the walk started.
    public struct Steps: Codable, Hashable, Sendable {
        public var t: Double
        public var steps: Int
        public var distance: Double?
        public var cadence: Double?
        public var pace: Double?
        public var floorsUp: Int?
        public var floorsDown: Int?
        public init(t: Double, steps: Int, distance: Double?, cadence: Double?, pace: Double?, floorsUp: Int?, floorsDown: Int?) {
            self.t = t; self.steps = steps; self.distance = distance; self.cadence = cadence; self.pace = pace
            self.floorsUp = floorsUp; self.floorsDown = floorsDown
        }
    }

    public struct StepEvent: Codable, Hashable, Sendable {
        public var t: Double
        /// "pause" or "resume".
        public var kind: String
        public init(t: Double, kind: String) { self.t = t; self.kind = kind }
    }

    public struct Activity: Codable, Hashable, Sendable {
        public var t: Double
        public var stationary: Bool
        public var walking: Bool
        public var running: Bool
        public var automotive: Bool
        public var unknown: Bool
        /// 0 low, 1 medium, 2 high.
        public var confidence: Int
        public init(t: Double, stationary: Bool, walking: Bool, running: Bool, automotive: Bool, unknown: Bool, confidence: Int) {
            self.t = t; self.stationary = stationary; self.walking = walking; self.running = running
            self.automotive = automotive; self.unknown = unknown; self.confidence = confidence
        }
    }

    /// The camera's position (m, from where AR mode started) and orientation; no images.
    public struct ARPose: Codable, Hashable, Sendable {
        public var t: Double
        public var p: [Double]
        public var q: [Double]
        /// "normal", "limited:<reason>" or "notAvailable".
        public var tracking: String
        /// The world-mapping status: notAvailable, limited, extending, mapped.
        public var mapping: String
        public init(t: Double, p: [Double], q: [Double], tracking: String, mapping: String) {
            self.t = t; self.p = p; self.q = q; self.tracking = tracking; self.mapping = mapping
        }
    }

    public struct Event: Codable, Hashable, Sendable {
        public var t: Double
        public var kind: String
        public var detail: String
        public init(t: Double, kind: String, detail: String = "") { self.t = t; self.kind = kind; self.detail = detail }
    }

    /// How long the walk ran, in seconds (to now while it's running).
    public func duration(now: Double = Date().timeIntervalSince1970) -> Double { (endedAt ?? now) - startedAt }

    public var markCount: Int { routes.reduce(0) { $0 + $1.marks.count } }
}

extension WalkLog {
    /// The routes Clack suggests at each station; ticked off in `checklist`, never required.
    public static let suggestedRoutes = [
        "Arriving platform → main exit",
        "Platform → another platform (underpass or bridge)",
        "Hall → buses or taxis",
        "A route with stairs or a lift",
        "One route twice: phone in hand, then AR on",
        "Slow lap of everything, marking every landmark",
    ]

    /// The file form: JSON compressed with zlib (raw DEFLATE, as Apple's `Compression` writes it). The server stores it
    /// as it is; the analysis inflates it (Node's `zlib.inflateRawSync`).
    public func compressed() throws -> Data {
        let json = try JSONEncoder().encode(self)
        return try (json as NSData).compressed(using: .zlib) as Data
    }

    public static func decompress(_ data: Data) throws -> WalkLog {
        let json = try (data as NSData).decompressed(using: .zlib) as Data
        return try JSONDecoder().decode(WalkLog.self, from: json)
    }
}
