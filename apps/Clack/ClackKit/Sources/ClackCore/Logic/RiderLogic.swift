import Foundation

/// The phone placing the train it is on (owner, 2026-10-30; docs/POSITIONING.md "Riders' reports"). On the phone:
/// the fix is snapped onto our track for the train's stretch (`GET /api/live/segment`), and only what that gives
/// may leave it, when "Help place trains for everyone" is on: the train, the stretch, how far along it (0–1), the
/// speed and the time, with a session id random per trip. Never the coordinates, never the user id.
public nonisolated enum RiderLogic {
    /// A fix further than this from the track is not on this train (or the track is wrong there): nothing is sent.
    public static let maxOffsetM = 60.0
    /// A fix less precise than this says too little to place a train.
    public static let maxAccuracyM = 50.0
    /// Slower than this the phone may be on a platform or the train standing, which the feeds place better.
    public static let movingKmh = 15.0
    /// Further than this along the track from where the feed has the train, the phone is taken to be on another train.
    public static let maxFromFeedM = 20_000.0
    /// How often a report goes, seconds (the owner's 15–30 s).
    public static let interval: TimeInterval = 20

    public struct Snap: Equatable, Sendable {
        /// Metres along the stretch, and 0–1 of its length.
        public let alongM: Double
        public let progress: Double
        public let speedKmh: Double
    }

    /// The fix on the train's track, or nil when it isn't believable as a rider on it: too imprecise, off the track,
    /// not moving like a train, or far from where the feed has the train (`feedProgress`, when it says).
    public static func snap(fix: LatLon, accuracyM: Double, speedMps: Double, track: ExploreLogic.TrackPath, feedProgress: Double?) -> Snap? {
        guard accuracyM >= 0, accuracyM <= maxAccuracyM, speedMps >= 0, track.length > 0 else { return nil }
        let kmh = speedMps * 3.6
        guard kmh >= movingKmh else { return nil }
        let p = track.project(fix)
        guard p.offsetM <= maxOffsetM else { return nil }
        if let feedProgress, abs(feedProgress * track.length - p.along) > maxFromFeedM { return nil }
        return Snap(alongM: p.along, progress: min(1, max(0, p.along / track.length)), speedKmh: kmh)
    }

    /// The body of `POST /api/live/report`: exactly what leaves the phone.
    public struct Report: Encodable, Equatable, Sendable {
        public let train: String
        public let prevId: String
        public let nextId: String
        public let progress: Double
        public let speedKmh: Double
        /// When the fix was taken, ms since 1970.
        public let at: Double
        public let session: String

        public init(train: String, prevId: String, nextId: String, progress: Double, speedKmh: Double, at: Double, session: String) {
            self.train = train
            self.prevId = prevId
            self.nextId = nextId
            // Rounded: a metre or so is all the server uses; nothing finer leaves the phone.
            self.progress = (progress * 10_000).rounded() / 10_000
            self.speedKmh = speedKmh.rounded()
            self.at = (at / 1000).rounded() * 1000
            self.session = session
        }
    }
}
