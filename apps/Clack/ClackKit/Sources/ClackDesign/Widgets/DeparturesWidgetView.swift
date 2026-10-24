//
//  DeparturesWidgetView.swift
//  ClackDesign
//
//  A station's departures as the board's compact rows: time, destination, delay, platform. As many rows as fit whole.
//

import ClackCore
import SwiftUI

public struct DeparturesWidgetView: View {
    var date: Date
    var size: WidgetSize
    var stationId: String?
    var stationName: String?
    var board: WidgetSnapshot.StationBoard?
    var language: Language
    var clock: ClockFormat
    var isPlaceholder: Bool

    public init(
        date: Date, size: WidgetSize, stationId: String?, stationName: String?, board: WidgetSnapshot.StationBoard?,
        language: Language, clock: ClockFormat, isPlaceholder: Bool = false
    ) {
        self.date = date
        self.size = size
        self.stationId = stationId
        self.stationName = stationName
        self.board = board
        self.language = language
        self.clock = clock
        self.isPlaceholder = isPlaceholder
    }

    private var l10n: L10n { WidgetWords.l10n(language) }

    public var body: some View {
        Group {
            if let board {
                ViewThatFits(in: .vertical) {
                    ForEach(rowCounts, id: \.self) { count in content(board, limit: count) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if stationId != nil {
                EmptyWidget(title: stationName ?? l10n.t("board.departures"), hint: l10n.t("board.error"))
            } else {
                EmptyWidget(title: l10n.t("widgets.pickStation"), hint: l10n.t("widgets.pickStationHint"))
            }
        }
        .environment(l10n)
        .placeholder(isPlaceholder)
    }

    /// The most rows first; one fewer each time they don't fit.
    private var rowCounts: [Int] { size == .large ? [8, 7, 6, 5] : [4, 3, 2] }

    private func content(_ board: WidgetSnapshot.StationBoard, limit: Int) -> some View {
        let rows = WidgetTimeline.departures(board.rows, at: wMs(date), limit: limit)
        let name = stationName ?? board.name
        return VStack(alignment: .leading, spacing: 8) {
            // The name with "Updated 12:04" beside it, or under it when both don't fit on the line.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(name).clack(.boardDestination).foregroundStyle(Ink.text).lineLimit(1).fixedSize()
                    Spacer(minLength: 0)
                    UpdatedLine(updatedAt: board.updatedAt, now: date, l10n: l10n, clock: clock)
                }
                VStack(alignment: .leading, spacing: 0) {
                    FittingText(name).clack(.boardDestination).foregroundStyle(Ink.text)
                    UpdatedLine(updatedAt: board.updatedAt, now: date, l10n: l10n, clock: clock)
                }
            }
            ForEach(rows) { row in
                // The board's compact row, as on a station sheet in the app.
                BoardRowView(
                    .init(
                        time: row.leaves, sched: row.time, tz: board.tz ?? TimeZone.current.identifier, destination: row.to,
                        platform: row.platform, delay: row.delayMin, canceled: row.canceled
                    ),
                    clock: clock, dense: true
                )
            }
            if rows.isEmpty { Text(l10n.t("board.empty")).clack(.caption).foregroundStyle(Ink.text2) }
            Spacer(minLength: 0)
        }
    }
}
