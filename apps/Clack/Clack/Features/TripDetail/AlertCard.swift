//
//  AlertCard.swift
//  Clack
//

import SwiftUI

/// severe: you need to act (cancelled, skipped stop, missed change, buses). warn: late or tight. watch: a warning
/// ahead. info: for the record.
enum AlertTone {
    case severe, warn, watch, info

    var color: Color {
        switch self {
        case .severe: Ink.veryLate
        case .warn: Ink.late
        case .watch: Ink.slight
        case .info: Ink.text2
        }
    }
}

/// Which alerts have been closed: hidden for that trip and situation; if the situation changes (another kind of
/// disruption, a new warning), the new alert shows (Alert.tsx).
enum DismissedAlerts {
    private static let key = "clack.dismissedAlerts"

    static func all(_ defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    static func contains(_ alert: String, _ defaults: UserDefaults = .standard) -> Bool {
        all(defaults).contains(alert)
    }

    static func dismiss(_ alert: String, _ defaults: UserDefaults = .standard) {
        defaults.set(Array((all(defaults) + [alert]).suffix(201)), forKey: key)
    }

    static func reset(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

/// Alerts on a trip (disruption help and delay warnings): set apart from the ordinary cards by a tinted header band
/// and body in the alert's tone, with a close button.
struct AlertCard<Content: View>: View {
    @Environment(L10n.self) private var l10n
    let tone: AlertTone
    let icon: String
    let title: String
    let dismissKey: String
    @ViewBuilder var content: Content
    @State private var hidden: Bool

    init(tone: AlertTone, icon: String, title: String, dismissKey: String, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.icon = icon
        self.title = title
        self.dismissKey = dismissKey
        self.content = content()
        _hidden = State(initialValue: DismissedAlerts.contains(dismissKey))
    }

    var body: some View {
        if !hidden {
            let tint = tone.color
            let watch = tone == .watch
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    LucideIcon(name: icon, size: 16)
                        .foregroundStyle(tone == .severe ? Color.white : Color(hex: "#0b0e13")!)
                        .frame(width: 30, height: 30)
                        .background(tint, in: Circle())
                    Text(title).clack(.alertTitle).foregroundStyle(Ink.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    Button {
                        DismissedAlerts.dismiss(dismissKey)
                        hidden = true
                    } label: {
                        LucideIcon(name: "x", size: 16).foregroundStyle(Ink.text).frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l10n.t("common.close"))
                }
                .padding(.vertical, 10).padding(.leading, 14).padding(.trailing, 10)
                .background(
                    LinearGradient(
                        colors: [tint.opacity(watch ? 0.18 : 0.34), tint.opacity(watch ? 0.04 : 0.08)],
                        startPoint: UnitPoint(x: 0.0, y: 0.35), endPoint: UnitPoint(x: 1, y: 0.65)
                    )
                )
                VStack(alignment: .leading, spacing: 12) { content }
                    .padding(.top, 14).padding(.bottom, 16).padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background {
                ZStack {
                    CSSLinearGradient(angle: 160, stops: [
                        .init(color: Ink.surfaceRaised, location: 0),
                        .init(color: Ink.surface, location: 0.6),
                        .init(color: Ink.surface, location: 1),
                    ])
                    // `color-mix(tone 8%, raised)` at the start: the tone laid over it, fading out by 60%.
                    if !watch {
                        CSSLinearGradient(angle: 160, stops: [
                            .init(color: tint.opacity(0.08), location: 0), .init(color: tint.opacity(0), location: 0.6),
                        ])
                    }
                    CSSRadialGradient(rx: 1.2, ry: 0.8, cx: 1, cy: 0, stops: [
                        .init(color: tint.opacity(watch ? 0.12 : 0.22), location: 0),
                        .init(color: tint.opacity(0), location: 0.6),
                    ])
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .hairlineBorder(radius: Radius.card, color: tint.opacity(watch ? 0.3 : 0.5))
            .accessibilityElement(children: .contain)
        }
    }
}
