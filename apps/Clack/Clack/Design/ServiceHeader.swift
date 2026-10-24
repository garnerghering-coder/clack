//
//  ServiceHeader.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The three sizes an operator badge comes in (DESIGN §2.5): 20 inline in a row of text, 28 on cards and sheets, 36 on
/// trip rows and a trip's page.
enum BadgeSize: CaseIterable {
    case small, medium, large

    var points: CGFloat {
        switch self {
        case .small: 20
        case .medium: 28
        case .large: 36
        }
    }
}

/// A train's header (DESIGN §2.5 ServiceHeader): the operator's badge, the service as people say it ("SJ 529"), and
/// optionally its category and a status line, wrapping onto a second line when they don't fit.
struct ServiceHeader<Status: View>: View {
    @Environment(L10n.self) private var l10n
    let op: (any OperatorDisplay)?
    let number: String?
    var size: BadgeSize = .medium
    /// The product key ("intercity", "regional"…) for the category written after the service.
    var category: String?
    /// What to say when neither the operator nor the number is known.
    var fallback: String?
    /// The service's own name, said instead of the operator's ("SJ InterCity"; a route name when the operator isn't known).
    var name: String?
    /// Where you sit, "Car 4 · Seat 23" (`Seat.label`), written after the service.
    var seat: String?
    @ViewBuilder var status: Status

    init(
        op: (any OperatorDisplay)?, number: String?, size: BadgeSize = .medium, category: String? = nil, name: String? = nil, fallback: String? = nil,
        seat: String? = nil, @ViewBuilder status: () -> Status
    ) {
        self.op = op
        self.number = number
        self.size = size
        self.category = category
        self.name = name
        self.fallback = fallback
        self.seat = seat
        self.status = status()
    }

    var body: some View {
        let service = Format.service(name ?? op?.name, number)
        FlowLayout(spacing: 8, lineSpacing: 4, centered: true) {
            OperatorBadge(op: op, size: size)
            Text(service.isEmpty ? (fallback ?? l10n.t("trips.train")) : service)
                .clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(1)
            if let category { Text(l10n.t("products.\(category)")).clack(.chip).foregroundStyle(Ink.text2).lineLimit(1) }
            if let seat { Text(seat).clack(.chip).foregroundStyle(Ink.text).lineLimit(1) }
            status
        }
        .accessibilityElement(children: .combine)
    }
}

extension ServiceHeader where Status == EmptyView {
    init(op: (any OperatorDisplay)?, number: String?, size: BadgeSize = .medium, category: String? = nil, name: String? = nil, fallback: String? = nil, seat: String? = nil) {
        self.init(op: op, number: number, size: size, category: category, name: name, fallback: fallback, seat: seat) { EmptyView() }
    }
}
