//
//  StationSceneView.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI
import UIKit

/// The station map (map/StationScene.tsx): a designed, schematic plan of one level at a time, not MapLibre. Geometry is
/// in metres; the plan is drawn in a `Canvas`, while pins, chips and labels are views at the projected points, so they
/// keep their screen size and stay upright however the plan is rotated or zoomed.
struct StationSceneView: View {
    typealias Mark = StationSceneLogic.PlatformMark
    typealias Pin = StationSceneLogic.PlacePin

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let map: StationMap
    let level: String
    let route: StationRoute?
    let marks: [Mark]
    var pins: [Pin] = []
    let poiState: (StationPoi) -> OpenState
    let dimPoi: (StationPoi) -> Bool
    let onPoi: (StationPoi) -> Void
    /// Change this to re-fit the view (when a route appears, or the floor changes).
    let fitKey: String
    var selectedPoi: String?
    var insets = StationSceneLogic.Insets()

    @State private var size = CGSize(width: 393, height: 700)
    @State private var view = StationSceneLogic.View()

    private var rotation: Double { map.view?.rotation ?? 0 }

    /// What the pins and chips are at a zoom: worked out once for each zoom, not for each frame of a pan.
    @State private var layouts = SceneLayoutCache()

    var body: some View {
        let layout = layouts.layout(map: map, level: level, marks: marks, k: view.k, state: poiState, dim: dimPoi)
        let chips = layout.chips
        let shown = layout.pois
        let levelChanges = route?.steps.filter { $0.from.level != $0.to.level && ($0.from.level == level || $0.to.level == level) } ?? []
        ZStack(alignment: .topLeading) {
            // One finger pans, two pinch around their midpoint: iOS's own recognizers, which handle both at once.
            SceneGestureLayer(
                onPan: { delta in view.tx += delta.width; view.ty += delta.height },
                onPinch: { factor, anchor in view = StationSceneLogic.zoom(view, by: factor, aroundX: anchor.x, y: anchor.y) }
            )
            TimelineView(.animation(paused: reduceMotion || route == nil)) { timeline in
                Canvas { context, _ in
                    draw(&context, phase: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.9) / 0.9)
                }
            }
            .allowsHitTesting(false)
            .accessibilityLabel(map.name)
            .accessibilityAddTraits(.isImage)

            ForEach(Array(levelChanges.enumerated()), id: \.offset) { _, step in
                let node = step.from.level == level ? step.from : step.to
                LucideIcon(name: "arrow-up-down", size: 14)
                    .foregroundStyle(Ink.bg)
                    .frame(width: 22, height: 22)
                    .background(Palette.path, in: Circle())
                    .position(screen(node.x, node.y))
                    .allowsHitTesting(false)
            }
            ForEach(chips) { chip in
                platformChip(chip).position(screen(chip.x, chip.y)).allowsHitTesting(false)
            }
            ForEach(map.pois.filter { $0.level == level && shown.shown.contains($0.id) }) { poi in
                poiPin(poi, named: shown.named.contains(poi.id)).position(screen(poi.x, poi.y))
            }
            ForEach(Array(pins.filter { $0.level == level }.enumerated()), id: \.offset) { _, pin in
                placePin(pin).position(screen(pin.x, pin.y)).allowsHitTesting(false)
            }
        }
        .background(Ink.mapBg)
        .clipped()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onAppear { refit() }
        .onChange(of: fitKey) { refit() }
        .onChange(of: size) { refit() }
        .onChange(of: map) { refit() }
        .onChange(of: insets) { refit() }
    }

    private func refit() {
        if let fitted = StationSceneLogic.fit(map: map, level: level, route: route, marks: marks, pins: pins, width: size.width, height: size.height, insets: insets) {
            view = fitted
        }
    }

    /// Where a world point is on screen.
    private func screen(_ x: Double, _ y: Double) -> CGPoint {
        let r = StationSceneLogic.rotate(x, y, degrees: rotation)
        return CGPoint(x: view.tx + r.x * view.k, y: view.ty + r.y * view.k)
    }

    // MARK: the plan

    private func draw(_ context: inout GraphicsContext, phase: Double) {
        let k = view.k
        context.translateBy(x: view.tx, y: view.ty)
        context.scaleBy(x: k, y: k)
        context.rotate(by: .degrees(rotation))
        func polygon(_ points: [Pt]) -> Path {
            var path = Path()
            for (i, p) in points.enumerated() { i == 0 ? path.move(to: CGPoint(x: p.x, y: p.y)) : path.addLine(to: CGPoint(x: p.x, y: p.y)) }
            path.closeSubpath()
            return path
        }
        func line(_ points: [Pt]) -> Path {
            var path = Path()
            for (i, p) in points.enumerated() { i == 0 ? path.move(to: CGPoint(x: p.x, y: p.y)) : path.addLine(to: CGPoint(x: p.x, y: p.y)) }
            return path
        }
        let onLevel = map.shapes.filter { $0.level == level }
        for shape in map.shapes where shape.kind == .building { context.fill(polygon(shape.points), with: .color(Ink.surface)) }
        // Other levels' platforms, for orientation.
        for platform in map.platforms where platform.level != level {
            for g in platform.geometry { context.fill(polygon(g), with: .color(Ink.text.opacity(0.05))) }
        }
        for shape in onLevel {
            switch shape.kind {
            case .hall: context.fill(polygon(shape.points), with: .color(Palette.hall))
            case .room:
                context.fill(polygon(shape.points), with: .color(Palette.hall))
                context.stroke(polygon(shape.points), with: .color(Ink.hairline), lineWidth: 0.6 / k)
            case .shop:
                context.fill(polygon(shape.points), with: .color(Palette.shop))
                context.stroke(polygon(shape.points), with: .color(Ink.mapBg), lineWidth: 0.6 / k)
            default: break
            }
        }
        for shape in onLevel where shape.kind == .track {
            context.stroke(line(shape.points), with: .color(Ink.text3.opacity(0.4)), style: StrokeStyle(lineWidth: 1.1 / k, lineCap: .round, lineJoin: .round))
        }
        // Places mapped as their own unit are drawn in their real shape, tinted by kind.
        for poi in map.pois where poi.level == level {
            guard let outline = poi.outline else { continue }
            context.fill(polygon(outline), with: .color(Palette.unit(poi.category)))
            context.stroke(polygon(outline), with: .color(Ink.mapBg), lineWidth: 0.6 / k)
        }
        // Platform pieces in one fill, so a platform reads as one shape.
        for platform in map.platforms where platform.level == level {
            for g in platform.geometry {
                context.fill(polygon(g), with: .color(Palette.platform))
                context.stroke(polygon(g), with: .color(Palette.platform), style: StrokeStyle(lineWidth: 0.5 / k, lineJoin: .round))
            }
        }
        if k > 2.2 {
            for node in map.nodes where node.level == level && (node.type == .stairs || node.type == .escalator || node.type == .lift) {
                let rect = CGRect(x: node.x - 2.5 / k, y: node.y - 2.5 / k, width: 5 / k, height: 5 / k)
                let colour = node.type == .lift ? Ink.text : Ink.text2.opacity(0.7)
                context.fill(Path(roundedRect: rect, cornerRadius: 1.2 / k), with: .color(colour))
            }
        }
        // The open place's unit, outlined over the plan.
        if let selectedPoi, let poi = map.pois.first(where: { $0.id == selectedPoi && $0.level == level }), let outline = poi.outline {
            context.fill(polygon(outline), with: .color(Palette.pathGlow))
            context.stroke(polygon(outline), with: .color(Palette.path), lineWidth: 2 / k)
        }
        // The route on this level: a glow, and dots marching toward the destination.
        for step in route?.steps ?? [] where step.from.level == level && step.to.level == level {
            let path = line(StationSceneLogic.stepPoints(step))
            context.stroke(path, with: .color(Palette.pathGlow), style: StrokeStyle(lineWidth: 10 / k, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(Palette.path), style: StrokeStyle(lineWidth: 4.5 / k, lineCap: .round, lineJoin: .round, dash: [0.001, 10 / k], dashPhase: -phase * 10 / k))
        }
    }

    // MARK: chips and pins

    private func platformChip(_ chip: StationSceneLogic.PlatformChip) -> some View {
        let marked = chip.mark != nil
        let width = marked ? max(40, Double(chip.label.count) * 6.6 + 16) : max(22, Double(chip.label.count) * 7.5 + 10)
        return Text(chip.label)
            .font(ClackFont.inter(marked ? 11.5 : 12, .bold))
            .monospacedDigit()
            .foregroundStyle(marked ? Color.white : Ink.text)
            .lineLimit(1)
            .frame(width: width, height: 22)
            .background(chip.mark.flatMap { Color(hex: $0.color) } ?? Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(marked ? Color.white : Ink.hairline, lineWidth: marked ? 1.5 : 1))
    }

    private func poiPin(_ poi: StationPoi, named: Bool) -> some View {
        let state = poiState(poi)
        let dim = dimPoi(poi) || state == .closed
        return Button {
            onPoi(poi)
        } label: {
            ZStack {
                Circle().fill(Ink.surfaceRaised).overlay(Circle().strokeBorder(Ink.hairline, lineWidth: 1)).frame(width: 24, height: 24)
                LucideIcon(name: StationSceneLogic.icon(poi.category), size: 15).foregroundStyle(Ink.text)
                Group {
                    if state == .unknown {
                        Text("?").font(ClackFont.inter(11, .heavy)).foregroundStyle(Ink.text2).offset(x: 12, y: -10)
                    } else {
                        Circle().fill(state == .open ? Ink.onTime : state == .closingSoon ? Ink.late : Ink.unknown)
                            .overlay(Circle().strokeBorder(Ink.surfaceRaised, lineWidth: 1.5))
                            .frame(width: 7.2, height: 7.2).offset(x: 9, y: -9)
                    }
                }
                if named {
                    Text(poi.name.count > 18 ? "\(poi.name.prefix(17))…" : poi.name)
                        .font(ClackFont.inter(10, .semibold)).foregroundStyle(Ink.text2)
                        .shadow(color: Ink.mapBg, radius: 0.1).shadow(color: Ink.mapBg, radius: 1.5)
                        .fixedSize().offset(y: 24)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .opacity(dim ? 0.32 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(poi.name.isEmpty ? poi.category.rawValue : poi.name)
    }

    private func placePin(_ pin: Pin) -> some View {
        let fill: Color = pin.kind == .me ? Palette.me : pin.kind == .to ? Ink.accent : Ink.text
        let text: Color = pin.kind == .me ? .white : pin.kind == .to ? Ink.onAccent : Ink.bg
        let label = pin.label.count > 28 ? "\(pin.label.prefix(27))…" : pin.label
        let width = min(190, Double(pin.label.count) * 6.4 + 18)
        return ZStack {
            if pin.kind == .me { Circle().fill(Palette.me.opacity(0.2)).frame(width: 32, height: 32) }
            Circle().fill(fill).frame(width: 13, height: 13).overlay(Circle().strokeBorder(Ink.mapBg, lineWidth: 2.5))
            Text(label).font(ClackFont.inter(11.5, .bold)).foregroundStyle(text).lineLimit(1)
                .frame(width: width, height: 22)
                .background(fill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .offset(y: -24)
        }
    }
}

/// Catches the finger on the plan: a pan and a pinch, reported as small steps so each adds to the view.
struct SceneGestureLayer: UIViewRepresentable {
    var onPan: (CGSize) -> Void
    var onPinch: (_ factor: Double, _ anchor: CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 2
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinch(_:)))
        pan.delegate = context.coordinator
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onPan = onPan
        context.coordinator.onPinch = onPinch
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPan: (CGSize) -> Void = { _ in }
        var onPinch: (Double, CGPoint) -> Void = { _, _ in }

        @objc func pan(_ g: UIPanGestureRecognizer) {
            let t = g.translation(in: g.view)
            onPan(CGSize(width: t.x, height: t.y))
            g.setTranslation(.zero, in: g.view)
        }

        @objc func pinch(_ g: UIPinchGestureRecognizer) {
            guard g.numberOfTouches >= 2 || g.state == .changed else { return }
            onPinch(Double(g.scale), g.location(in: g.view))
            g.scale = 1
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

/// The chips and pins for one zoom, kept while the zoom, floor, chips and filters stay the same (panning changes
/// none of them), so a pan only moves what is already worked out.
@MainActor
final class SceneLayoutCache {
    struct Layout {
        var chips: [StationSceneLogic.PlatformChip]
        var pois: (shown: Set<String>, named: Set<String>)
    }

    private var key: Key?
    private var cached: Layout?

    private struct Key: Equatable {
        var k: Double
        var level: String
        var marks: [StationSceneLogic.PlatformMark]
        var states: [String: Int]
        var dimmed: Set<String>
    }

    func layout(map: StationMap, level: String, marks: [StationSceneLogic.PlatformMark], k: Double, state: (StationPoi) -> OpenState, dim: (StationPoi) -> Bool) -> Layout {
        // The inputs that decide the pins: each place on this floor with its open state and whether it's dimmed.
        var states: [String: Int] = [:]
        var dimmed = Set<String>()
        for p in map.pois where p.level == level {
            states[p.id] = StationSceneLogic.stateRank(state(p))
            if dim(p) { dimmed.insert(p.id) }
        }
        let next = Key(k: k, level: level, marks: marks, states: states, dimmed: dimmed)
        if let cached, key == next { return cached }
        let layout = Layout(
            chips: StationSceneLogic.platformChips(map: map, level: level, marks: marks, k: k),
            pois: StationSceneLogic.shownPois(map: map, level: level, k: k, state: state, dim: dim)
        )
        key = next
        cached = layout
        return layout
    }
}

/// The station map's own colours (styles.css `:root` station-map variables), per theme.
private enum Palette {
    private static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light) ?? .gray)
        })
    }

    static let path = dynamic(light: "#0a0a0a", dark: "#f8d64a")
    static let pathGlow = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 248 / 255, green: 214 / 255, blue: 74 / 255, alpha: 0.28) : UIColor(red: 248 / 255, green: 214 / 255, blue: 74 / 255, alpha: 0.55)
    })
    static let platform = dynamic(light: "#dcdcdc", dark: "#2a2a2a")
    static let hall = dynamic(light: "#efefef", dark: "#1b1b1b")
    static let shop = dynamic(light: "#e6e6e6", dark: "#222222")
    static let me = dynamic(light: "#1a6ff0", dark: "#3b8bff")
    private static let unitFill = dynamic(light: "#e2e2e2", dark: "#2b2b2b")
    private static let unitFood = dynamic(light: "#ece4d6", dark: "#33302a")
    private static let unitService = dynamic(light: "#dde5ec", dark: "#2a2f33")

    static func unit(_ category: PoiCategory) -> Color {
        switch category {
        case .cafe, .restaurant: unitFood
        case .pharmacy, .ticket, .info, .atm: unitService
        default: unitFill
        }
    }
}
