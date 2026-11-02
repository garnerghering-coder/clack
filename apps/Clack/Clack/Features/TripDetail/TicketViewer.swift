//
//  TicketViewer.swift
//  Clack
//

import ClackCore
import ClackDesign
import PassKit
import PDFKit
import SwiftUI

/// The ticket kept with a trip, full screen, opened at this train's page. The screen is at full brightness while it's
/// open, so a conductor's scanner reads the code, and back to what it was after.
struct TicketViewer: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let leg: Leg

    @State private var confirmDelete = false
    @State private var brightness: CGFloat?

    var body: some View {
        let entry = TicketStore.shared.entry(for: leg.id)
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(l10n.t("ticket.title")).clack(.sheetTitle).foregroundStyle(Ink.text).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                IconButton(icon: "x", label: l10n.t("common.close")) { dismiss() }
            }
            .padding(.top, 20).padding(.horizontal, 16).padding(.bottom, 8)
            if let url = TicketStore.shared.url(for: leg.id), let entry {
                TicketPDFView(url: url, page: entry.page)
                    .accessibilityLabel(l10n.t("ticket.title"))
                VStack(spacing: 12) {
                    if let barcode = entry.barcode {
                        WalletPassButton(leg: leg, issuer: entry.issuer, barcode: barcode)
                    }
                    Button(l10n.t("ticket.delete")) { confirmDelete = true }
                        .buttonStyle(ClackButtonStyle(kind: .danger, small: true))
                }
                .padding(16)
            } else {
                Text(l10n.t("ticket.missing")).clack(.body).foregroundStyle(Ink.text2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
            }
        }
        .background(Ink.surface)
        .confirmationDialog(l10n.t("ticket.deleteConfirm"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(l10n.t("ticket.delete"), role: .destructive) {
                TicketStore.shared.detach(legId: leg.id)
                dismiss()
            }
            Button(l10n.t("common.close"), role: .cancel) {}
        }
        .onAppear { brighten() }
        .onDisappear { restore() }
        .onChange(of: scenePhase) { _, phase in phase == .active ? brighten() : restore() }
        .countsScreen("ticket")
    }

    private var screen: UIScreen? {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
    }

    private func brighten() {
        guard brightness == nil, let screen else { return }
        brightness = screen.brightness
        screen.brightness = 1
    }

    private func restore() {
        guard let old = brightness, let screen else { return }
        screen.brightness = old
        brightness = nil
    }
}

/// PDFKit's own viewer, scaled to the width and opened at a page.
private struct TicketPDFView: UIViewRepresentable {
    let url: URL
    let page: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        if let target = view.document?.page(at: page) { view.go(to: target) }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}

/// "Add to Apple Wallet" for a kept ticket's code: the server signs a pass with the same code, PassKit offers it. A
/// test tool (Settings, test builds only) until docs/TICKET_WALLET_FINDINGS.md says each operator accepts it.
struct WalletPassButton: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @AppStorage(WalletPassButton.settingKey) private var enabled = false
    let leg: Leg
    let issuer: TicketTrain.Issuer
    let barcode: TicketBarcode

    static let settingKey = "clack.test.walletPasses"

    @State private var testBuild = false
    @State private var pass: PKPass?
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        VStack(spacing: 8) {
            if testBuild && enabled && PKAddPassesViewController.canAddPasses() {
                AddPassButton { Task { await fetch() } }
                    .frame(height: 48)
                    .disabled(busy)
                    .accessibilityIdentifier("ticket.wallet")
                if failed { Text(l10n.t("ticket.walletFailed")).clack(.caption).foregroundStyle(Ink.text2) }
            }
        }
        .task { testBuild = await WalkStore.isTestBuild() }
        .sheet(item: $pass) { AddPassSheet(pass: $0) }
    }

    private func fetch() async {
        guard let dep = leg.schedDep?.ms else { return }
        busy = true
        failed = false
        defer { busy = false }
        let body = WalletPassBody(
            issuer: issuer, operatorName: leg.operator?.name, trainNumber: leg.trainNumber,
            from: leg.origin?.name ?? "", to: leg.destination?.name ?? "", depAt: dep, arrAt: leg.schedArr?.ms,
            coach: leg.coach, seat: leg.seat, barcode: barcode, lang: app.settings.language.rawValue
        )
        do {
            pass = try PKPass(data: try await app.client.walletPass(body))
        } catch {
            failed = true
        }
    }
}

extension PKPass: @retroactive Identifiable {
    public var id: String { serialNumber }
}

/// PassKit's "Add to Apple Wallet" button.
private struct AddPassButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .black) // design-lint: allow PassKit's own button style, not a colour
        button.addTarget(context.coordinator, action: #selector(Coordinator.tap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ button: PKAddPassButton, context: Context) { context.coordinator.action = action }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tap() { action() }
    }
}

/// PassKit's own sheet that shows the pass and adds it.
private struct AddPassSheet: UIViewControllerRepresentable {
    let pass: PKPass

    func makeUIViewController(context: Context) -> UIViewController {
        PKAddPassesViewController(pass: pass) ?? UIViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
