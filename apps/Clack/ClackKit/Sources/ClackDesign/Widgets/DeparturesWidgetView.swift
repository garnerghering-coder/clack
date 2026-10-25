//
//  DeparturesWidgetView.swift
//  ClackDesign
//
//  A station's departures as a departure board (owner, 2026-10-25: "make it look like a real timeboard"): the station
//  in a header strip, then rows of split-flap times, the destination in the board face, the delay, and the platform in
//  a fixed column (a dash when not known), with hairlines between. As many rows as fit whole.
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
    private var rowCounts: [Int] { size == .large ? [7, 6, 5, 4] : [3, 2, 1] }

    /// The board's lettering: the display face, as on a station's split-flap board.
    private static let boardFace = TextRole(size: 15, lineHeight: 20, display: true, style: .subheadline)

    private func content(_ board: WidgetSnapshot.StationBoard, limit: Int) -> some View {
        let rows = WidgetTimeline.departures(board.rows, at: wMs(date), limit: limit)
        let name = stationName ?? board.name
        let tz = board.tz ?? TimeZone.current.identifier
        return VStack(alignment: .leading, spacing: 0) {
            // The header strip: the station, "Departures", and "Updated 12:04" once the data is old.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                FittingText(name).clack(Self.boardFace).foregroundStyle(Ink.text)
                Spacer(minLength: 0)
                UpdatedLine(updatedAt: board.updatedAt, now: date, l10n: l10n, clock: clock)
                Text(l10n.t("board.departures")).clack(.captionUpper).foregroundStyle(Ink.accentInk).lineLimit(1).fixedSize()
            }
            .padding(.bottom, 8)
            ForEach(rows) { row in
                Rectangle().fill(Ink.hairline).frame(height: 1)
                HStack(spacing: 8) {
                    SplitFlap(
                        value: Format.time(row.leaves, tz: tz, clock: clock), size: .sm,
                        colour: row.canceled ? DelayBand.cancelled.ink : (row.delayMin ?? 0) >= 1 ? DelayBand(delayMin: row.delayMin, canceled: false).ink : nil
                    )
                    Text(row.to).clack(Self.boardFace).foregroundStyle(row.canceled ? Ink.text3 : Ink.text)
                        .strikethrough(row.canceled).lineLimit(1)
                        // One size on every row, as on a real board: a long name is cut rather than shrunk.
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    if row.canceled {
                        DelayText(delay: nil, canceled: true)
                    } else if let d = row.delayMin, d != 0 {
                        DelayText(delay: d)
                    }
                    Group {
                        if let p = row.platform { PlatformTag(platform: p) } else { UnknownPlatformTag() }
                    }
                    .frame(minWidth: 36, alignment: .trailing)
                }
                .padding(.vertical, 6)
            }
            if rows.isEmpty { Text(l10n.t("board.empty")).clack(.caption).foregroundStyle(Ink.text2) }
            Spacer(minLength: 0)
        }
    }
}
