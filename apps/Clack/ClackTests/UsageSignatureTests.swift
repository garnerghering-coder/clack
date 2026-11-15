//
//  UsageSignatureTests.swift
//  ClackTests
//

import Foundation
import Testing
@testable import Clack

/// A crash report's short signature names where it crashed (build 87: both crashes of build 83 came through with no
/// frame at all).
struct UsageSignatureTests {
    /// Apple's call stack tree shape, with the keys in the order that defeated the old pattern.
    private let report = """
    {"callStackPerThread": true, "callStacks": [
      {"threadAttributed": false, "callStackRootFrames": [{"offsetIntoBinaryTextSegment": 1, "binaryName": "libsystem_kernel.dylib"}]},
      {"threadAttributed": true, "callStackRootFrames": [
        {"offsetIntoBinaryTextSegment": 100, "binaryName": "libsystem_kernel.dylib", "subFrames": [
          {"offsetIntoBinaryTextSegment": 200, "binaryName": "Foundation", "subFrames": [
            {"offsetIntoBinaryTextSegment": 300, "binaryName": "UIKitCore", "subFrames": [
              {"offsetIntoBinaryTextSegment": 400, "binaryName": "UIKitCore", "subFrames": [
                {"offsetIntoBinaryTextSegment": 500, "binaryName": "UIKitCore", "subFrames": [
                  {"offsetIntoBinaryTextSegment": 12345, "binaryName": "Clack"}
                ]}
              ]}
            ]}
          ]}
        ]}
      ]}
    ]}
    """

    @Test func theCrashedThreadsTopFramesAndClacksOwnAreKept() {
        let s = Usage.signature("exception 10 signal 6", json: Data(report.utf8))
        #expect(s == "exception 10 signal 6 · libsystem_kernel.dylib+100 > Foundation+200 > UIKitCore+300 > UIKitCore+400 > Clack+12345")
    }

    @Test func anUnreadableTreeStillSaysWhatHappened() {
        #expect(Usage.signature("exception 1 signal 11", json: Data("nope".utf8)) == "exception 1 signal 11")
        #expect(Usage.signature("", json: Data("{}".utf8)) == "unknown")
    }
}
