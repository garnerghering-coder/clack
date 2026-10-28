//
//  WalkScreens.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Settings > Station walks (owner test tool, TestFlight and debug builds): record walks through stations with every
/// sensor, add your own routes, marks and notes, edit them afterwards, export them, and upload them for the station
/// work. Plain English: this is a tool for the owner, not a user-facing screen.
struct WalkLoggerScreen: View {
    @Environment(AppModel.self) private var app
    @State private var store = WalkStore.shared
    @State private var recorder = WalkRecorder.shared
    @State private var newTitle = ""
    @State private var editing: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if recorder.isRecording {
                    WalkSessionView(recorder: recorder)
                } else {
                    Card {
                        Text("New walk").clack(.sectionHeader).foregroundStyle(Ink.text2)
                        TextField("Station and what you're doing, e.g. Jönköping C", text: $newTitle)
                            .textFieldStyle(.roundedBorder)
                        Button("Start walk") {
                            recorder.start(title: newTitle)
                            newTitle = ""
                        }
                        .buttonStyle(.clack(wide: true))
                        Text("Keep Clack open while you walk: iOS pauses the motion sensors when an app is in the background. The screen stays on by itself.")
                            .clack(.caption).foregroundStyle(Ink.text2)
                    }
                }
                Card {
                    Text("Saved walks").clack(.sectionHeader).foregroundStyle(Ink.text2)
                    if store.entries.isEmpty {
                        Text("None yet.").clack(.body).foregroundStyle(Ink.text2)
                    }
                    ForEach(store.entries) { e in
                        Button { editing = e.id } label: { WalkRow(entry: e, uploading: store.uploading.contains(e.id)) }
                            .buttonStyle(.plain)
                    }
                    if let error = store.lastError {
                        Text(error).clack(.caption).foregroundStyle(Ink.text2)
                    }
                }
            }
            .padding(16)
        }
        .screenTitle("Station walks")
        .sheet(item: Binding(get: { editing.map(EditID.init) }, set: { editing = $0?.id })) { item in
            WalkEditView(store: store, id: item.id)
        }
        .task {
            store.client = app.client
            // Every minute while this screen is open: anything not yet on the server goes up.
            while !Task.isCancelled {
                store.uploadPending(except: recorder.log?.id)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private struct EditID: Identifiable { let id: String }
}

private struct WalkRow: View {
    let entry: WalkStore.Entry
    let uploading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title).clack(.rowTitle).foregroundStyle(Ink.text)
            Text("\(Date(timeIntervalSince1970: entry.startedAt).formatted(date: .abbreviated, time: .shortened)) · \(Int(entry.duration / 60)) min · \(entry.routes) routes · \(entry.marks) marks · \(ByteCountFormatter.string(fromByteCount: Int64(entry.bytes), countStyle: .file))")
                .clack(.caption).foregroundStyle(Ink.text2)
            Text(uploading ? "Uploading…" : entry.uploaded ? "Uploaded" : "Not uploaded yet")
                .clack(.caption).foregroundStyle(entry.uploaded ? Ink.text2 : Ink.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

/// While a walk runs: routes, marks (typed or dictated with the keyboard's microphone), the checklist, AR mode, and
/// live readings so you can see the sensors are working.
private struct WalkSessionView: View {
    @Bindable var recorder: WalkRecorder
    @Environment(\.scenePhase) private var scenePhase
    @State private var routeName = ""
    @State private var markLabel = ""
    @State private var routeNote = ""
    @FocusState private var markFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Card {
                Text(recorder.log?.title ?? "").clack(.sectionHeader).foregroundStyle(Ink.text2)
                readings
                if let problem = recorder.problem { Text(problem).clack(.caption).foregroundStyle(Ink.text) }
            }
            Card {
                if let route = recorder.currentRoute {
                    Text("Route: \(route.name)").clack(.rowTitle).foregroundStyle(Ink.text)
                    Text("\(route.marks.count) marks").clack(.caption).foregroundStyle(Ink.text2)
                    TextField("What's here? e.g. bottom of stairs to platform 2", text: $markLabel)
                        .textFieldStyle(.roundedBorder)
                        .focused($markFocused)
                        .submitLabel(.done)
                        .onSubmit(addMark)
                    Button("Mark here", action: addMark).buttonStyle(.clack(wide: true))
                    TextField("Note for this route (optional)", text: $routeNote).textFieldStyle(.roundedBorder)
                    Button("End route") {
                        recorder.endRoute(note: routeNote)
                        routeNote = ""
                    }
                    .buttonStyle(.clack(wide: true))
                } else {
                    TextField("Route name, e.g. platform 2 → main exit", text: $routeName).textFieldStyle(.roundedBorder)
                    Button("Start route") {
                        recorder.startRoute(name: routeName)
                        routeName = ""
                    }
                    .buttonStyle(.clack(wide: true))
                    Text("Marks made without a route start one by themselves.").clack(.caption).foregroundStyle(Ink.text2)
                }
            }
            Card {
                Toggle("AR mode (camera tracks movement; no pictures saved)", isOn: Binding(get: { recorder.arOn }, set: { recorder.setAR($0) }))
                    .clack(.body)
            }
            Card {
                Text("Suggested (optional)").clack(.sectionHeader).foregroundStyle(Ink.text2)
                ForEach(WalkLog.suggestedRoutes, id: \.self) { item in
                    let done = recorder.log?.checklist.contains(item) ?? false
                    Button { recorder.toggleChecklist(item) } label: {
                        HStack(alignment: .top, spacing: 8) {
                            LucideIcon(name: done ? "system:checkmark.square" : "system:square", size: 18)
                            Text(item).clack(.body).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(Ink.text)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("Stop walk and save") { recorder.stop() }.buttonStyle(.clack(wide: true))
        }
        .onChange(of: scenePhase) { _, phase in recorder.noteScenePhase(phase) }
    }

    private func addMark() {
        recorder.mark(markLabel)
        markLabel = ""
    }

    private var readings: some View {
        let log = recorder.log
        let loc = recorder.lastLocation
        return VStack(alignment: .leading, spacing: 2) {
            Text("Time \(Int((log?.duration() ?? 0) / 60)) min · steps \(recorder.lastSteps)")
            Text(loc.map { String(format: "Position ±%.0f m%@", $0.horizontalAccuracy, $0.floor.map { " · floor \($0.level)" } ?? "") } ?? "Position: waiting")
            Text(recorder.lastRelAlt.map { String(format: "Barometer %+.1f m", $0) } ?? "Barometer: waiting")
            Text("Samples: \(log?.location.count ?? 0) position · \(log?.motion.count ?? 0) motion · \(log?.pressure.count ?? 0) pressure · \(log?.ar.count ?? 0) AR")
        }
        .clack(.caption).foregroundStyle(Ink.text2)
    }
}

/// A saved walk: rename it and its routes, edit marks and notes, add marks you forgot (at the route's end), export,
/// upload again, or delete.
private struct WalkEditView: View {
    let store: WalkStore
    let id: String
    @Environment(\.dismiss) private var dismiss
    @State private var log: WalkLog?
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                if let binding = Binding($log) {
                    Section("Walk") {
                        TextField("Title", text: binding.title)
                        TextField("Note", text: binding.note, axis: .vertical)
                    }
                    ForEach(binding.routes) { $route in
                        Section(route.name) {
                            TextField("Route name", text: $route.name)
                            TextField("Note", text: $route.note, axis: .vertical)
                            ForEach($route.marks) { $mark in
                                TextField("Mark", text: $mark.label)
                            }
                            .onDelete { route.marks.remove(atOffsets: $0) }
                            Button("Add a mark at the end of this route") {
                                route.marks.append(.init(t: route.endedAt ?? route.startedAt, label: "Added afterwards"))
                            }
                        }
                    }
                    Section {
                        if let url = store.exportURL(id) {
                            ShareLink("Export (AirDrop, Files, Mail)", item: url)
                        }
                        Button("Upload again") { store.update(binding.wrappedValue) }
                        Button("Delete walk", role: .destructive) { confirmDelete = true }
                    }
                } else {
                    Text("This walk can't be read.")
                }
            }
            .navigationTitle(log?.title ?? "Walk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let log { store.update(log) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .confirmationDialog("Delete this walk from the phone? A copy already uploaded stays on the server.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.delete(id)
                    dismiss()
                }
            }
        }
        .onAppear { log = store.load(id) }
    }
}
