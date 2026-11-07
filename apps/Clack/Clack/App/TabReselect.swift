//
//  TabReselect.swift
//  Clack
//

import SwiftUI
import UIKit

/// Tells when the tab that is already showing is tapped again, so it can go back to its first screen as the system's
/// apps do. SwiftUI has no callback for it, and on iOS 26 the TabView doesn't call its selection binding when the value
/// is the same (user test 2026-11-07, run 2: tapping Trips on a trip stayed on the trip). A tap recognizer on the
/// system's tab bar that never blocks a touch notes which tab was selected when the finger came down; if it is still
/// the selected one after the tap, the tab was tapped again.
struct TabReselectHook: UIViewRepresentable {
    let onReselect: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> HookView {
        let view = HookView()
        view.coordinator = context.coordinator
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: HookView, context: Context) {
        context.coordinator.onReselect = onReselect
    }

    final class HookView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            // The tab bar controller is made with the window's content; look again on the next turn if it isn't yet.
            DispatchQueue.main.async { [weak self] in self?.attach() }
        }

        private func attach() {
            guard let coordinator, let root = window?.rootViewController, let tabs = Self.find(in: root) else { return }
            coordinator.attach(to: tabs)
        }

        private static func find(in controller: UIViewController) -> UITabBarController? {
            if let tabs = controller as? UITabBarController { return tabs }
            for child in controller.children { if let found = find(in: child) { return found } }
            return controller.presentedViewController.flatMap { find(in: $0) }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onReselect: (Int) -> Void = { _ in }
        private weak var tabs: UITabBarController?
        private var recognizer: UITapGestureRecognizer?
        private var selectedAtTouch: Int?

        func attach(to tabs: UITabBarController) {
            guard self.tabs !== tabs else { return }
            if let recognizer { recognizer.view?.removeGestureRecognizer(recognizer) }
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            tabs.tabBar.addGestureRecognizer(tap)
            self.tabs = tabs
            recognizer = tap
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            selectedAtTouch = tabs?.selectedIndex
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        @objc private func tapped() {
            guard let before = selectedAtTouch else { return }
            // After the tab bar has handled the same tap: a different tab chosen means it wasn't a reselect.
            DispatchQueue.main.async { [weak self] in
                guard let self, let tabs = self.tabs, tabs.selectedIndex == before else { return }
                self.onReselect(before)
            }
        }
    }
}
