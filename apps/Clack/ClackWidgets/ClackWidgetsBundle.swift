//
//  ClackWidgetsBundle.swift
//  ClackWidgets
//

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
