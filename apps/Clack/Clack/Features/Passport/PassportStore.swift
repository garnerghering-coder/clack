//
//  PassportStore.swift
//  Clack
//

import ClackCore
import SwiftUI

/// The Passport the tab loaded (its year and commuter scope), kept for the screens pushed from it (the breakdown, the
/// milestones, the full-screen map), so they open at once with the same numbers instead of fetching again. A screen
/// that opens with nothing here (a cold stack) loads its own.
@MainActor @Observable
final class PassportStore {
    var data: Passport?
    var year: Int?
}
