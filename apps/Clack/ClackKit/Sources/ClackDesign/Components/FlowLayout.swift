//
//  FlowLayout.swift
//  ClackDesign
//

import SwiftUI

/// Lays its children out in rows, wrapping to the next row when one doesn't fit (flex-wrap). `centered` lines the
/// children of a row up on their middles (a badge beside text) instead of their tops.
public struct FlowLayout: Layout {
    public var spacing: CGFloat = 8
    public var lineSpacing: CGFloat = 8
    public var centered = false

    public init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8, centered: Bool = false) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.centered = centered
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var rows: [(range: Range<Int>, height: CGFloat)] = []
        var rowStart = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                rows.append((rowStart..<index, rowHeight))
                rowStart = index
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        rows.append((rowStart..<subviews.count, rowHeight))
        if centered {
            for row in rows {
                for i in row.range { frames[i].origin.y += (row.height - frames[i].height) / 2 }
            }
        }
        return (CGSize(width: width, height: y + rowHeight), frames)
    }
}
