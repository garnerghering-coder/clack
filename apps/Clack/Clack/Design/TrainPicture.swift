//
//  TrainPicture.swift
//  Clack
//

import ClackCore
import SwiftUI

/// The train's picture: the drawn side view from the asset catalog (`scripts/ios/sync_assets.py` copies the drawings),
/// in the operator's livery when it has been drawn, unpainted when it hasn't, or the nearest drawn model fading out
/// from the back when the train's own isn't drawn (docs/SWIFT_PORT.md B7).
struct TrainPicture: View {
    let type: TrainType?
    let operatorId: String?
    /// Rendered height; the drawing keeps its proportions.
    var height: CGFloat = 56
    var label: String?

    var body: some View {
        let picture = TrainArt.picture(typeId: type?.id, art: type?.art, uncertain: type?.uncertain ?? false, operatorId: operatorId)
        let image = Image(picture.asset)
            .resizable()
            .scaledToFit()
            .frame(height: height)
        Group {
            if picture.isStandIn {
                image
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.6), .init(color: .black, location: 1)], startPoint: .leading, endPoint: .trailing))
                    .opacity(picture.isUnknown ? 0.45 : 0.8)
            } else {
                image
            }
        }
        .accessibilityLabel(label ?? "")
        .accessibilityHidden(label == nil)
    }
}
