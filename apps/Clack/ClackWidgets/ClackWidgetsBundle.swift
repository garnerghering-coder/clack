//
//  ClackWidgetsBundle.swift
//  ClackWidgets
//

import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

@main
struct ClackWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TripLiveActivity()
        NextJourneyWidget()
        PassportWidget()
        DeparturesWidget()
        YearWidget()
        StatsWidget()
    }
}
