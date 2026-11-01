import Foundation
import Testing
@testable import ClackCore

struct WalkLogMeshTests {
    @Test func aWalkFromBeforeLiDAROpensAndAMeshSurvivesSaving() throws {
        var log = WalkLog(title: "Test", startedAt: 1_800_000_000, device: .init(model: "iPhone", system: "iOS 27", appBuild: "54"))
        // An older walk: no "meshes" key at all.
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(log)) as! [String: Any]
        json.removeValue(forKey: "meshes")
        let old = try JSONDecoder().decode(WalkLog.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.meshes == nil)
        // One triangle, stored as binary.
        let floats: [Float] = [0, 0, 0, 1, 0, 0, 0, 1, 0]
        let vertices = floats.withUnsafeBytes { Data($0) }
        let faces = [UInt32(0), 1, 2].withUnsafeBytes { Data($0) }
        log.meshes = [.init(t: 1_800_000_060, vertexCount: 3, faceCount: 1, vertices: vertices, faces: faces, classes: Data([2]))]
        let back = try WalkLog.decompress(log.compressed())
        #expect(back.meshes?.first?.faceCount == 1)
        #expect(back.meshes?.first?.vertices == vertices)
        #expect(back.meshes?.first?.classes == Data([2]))
    }
}
