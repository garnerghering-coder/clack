//
//  TripDetailScreen.swift
//  Clack
//

import SwiftUI

/// One trip. Only the header so far: the full screen (stages, disruption, on board, stops) is step 6.
struct TripDetailScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let id: String
    @State private var detail: LegDetail?
    @State private var missing = false

    var body: some View {
        Page {
            BackLink(label: l10n.t("nav.trips"))
            if missing {
                Text(l10n.t("detail.notFound")).clack(.body).foregroundStyle(Ink.text2)
            } else if let leg = detail?.leg {
                Text("\(leg.origin?.name ?? "") → \(leg.destination?.name ?? "")")
                    .clack(.detailRoute).foregroundStyle(Ink.text)
                LegRow(leg: leg)
            } else {
                Skeleton(height: 120)
            }
        }
        .task(id: id) {
            do {
                detail = try await app.client.leg(id)
            } catch let error as APIError where error.status == 404 {
                missing = true
            } catch {
                missing = true
            }
        }
    }
}
