//
//  NotificationArt.swift
//  Clack
//

import SwiftUI
import UserNotifications

/// The picture on an alert: the train in the operator's colours on the board's dark ground. Shown as a small square on the
/// banner and full width when the alert is pressed and held. (Alerts that come from the server can't carry it without a
/// notification service extension, which needs the paid Apple team; local alerts can.)
@MainActor
enum NotificationArt {
    static let sound = UNNotificationSound(named: UNNotificationSoundName("sbb_jingle.wav"))

    static func attachment(type: TrainType?, operatorId: String?, colorHex: String?) -> UNNotificationAttachment? {
        let colour = Color(hex: colorHex ?? "#F8D64A") ?? Ink.accent
        let card = ZStack {
            LinearGradient(colors: [colour.opacity(0.9), Color(hex: "#0A0A0A")!], startPoint: .topLeading, endPoint: .bottomTrailing)
            TrainPicture(type: type, operatorId: operatorId, height: 96).padding(.horizontal, 16)
        }
        .frame(width: 400, height: 200)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let png = renderer.uiImage?.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("alert-art-\(UUID().uuidString).png")
        guard (try? png.write(to: url)) != nil else { return nil }
        // The banner shows a square: the middle of the picture, where the train is.
        let square = CGRect(x: 0.25, y: 0, width: 0.5, height: 1).dictionaryRepresentation as NSDictionary
        return try? UNNotificationAttachment(identifier: "art", url: url, options: [UNNotificationAttachmentOptionsThumbnailClippingRectKey: square])
    }
}
