import AppKit
import CoreText
import MarkerCore
import SwiftUI

@main
struct MarkTheRoughcutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = PlayerModel()

    init() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "fonts") ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        Window("MarkTheRoughcut", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 900, minHeight: 560)
                .onAppear {
                    delegate.model = model
                    Keys.install(model)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Video…") { openVideo(model) }.keyboardShortcut("o")
            }
            CommandMenu("Markers") {
                Button("Import Avid Markers…") { importMarkers(model) }.keyboardShortcut("i", modifiers: [.command, .shift])
                    .disabled(model.info == nil)
                Button("Export Avid Markers…") { exportMarkers(model) }.keyboardShortcut("e")
                    .disabled(model.info == nil || model.markers.isEmpty)
                Divider()
                Button("Change Name…") { model.needsName = true }
            }
        }
    }
}

/// Opening videos from the Finder ("Open With", drag onto the Dock icon).
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor var model: PlayerModel? {
        didSet { if let model, let url = pending { pending = nil; Task { await model.open(url) } } }
    }
    @MainActor private var pending: URL?

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        MainActor.assumeIsolated {
            if let model { Task { await model.open(url) } } else { pending = url }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Avid-like keys. Plain letters only act while no text field is being edited.
@MainActor
enum Keys {
    private static var monitor: Any?

    static func install(_ model: PlayerModel) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            handle(e, model) ? nil : e
        }
    }

    private static func handle(_ e: NSEvent, _ model: PlayerModel) -> Bool {
        // dialogs (name sheet, open/save panels) get every key untouched
        if NSApp.keyWindow?.sheetParent != nil || NSApp.modalWindow != nil { return false }
        let typing = NSApp.keyWindow?.firstResponder is NSTextView
        if typing {
            // Esc or Enter leaves the comment and gives the keys back to the player
            if e.keyCode == 53 || (e.keyCode == 36 && !e.modifierFlags.contains(.shift)) {
                NSApp.keyWindow?.makeFirstResponder(nil)
                return true
            }
            return false
        }
        guard model.info != nil, NSApp.keyWindow?.attachedSheet == nil else { return false }
        let mods = e.modifierFlags.intersection([.command, .option, .shift, .control])
        if mods.contains(.command) || mods.contains(.control) { return false }
        let fps = model.info?.format.fps ?? 25
        switch e.keyCode {
        case 49: model.togglePlay()
        case 123: mods.contains(.option) ? model.jumpMarker(forward: false) : model.step(mods.contains(.shift) ? -fps : -1)
        case 124: mods.contains(.option) ? model.jumpMarker(forward: true) : model.step(mods.contains(.shift) ? fps : 1)
        case 126: model.zoom(in: true)
        case 125: model.zoom(in: false)
        case 115: model.step(-Int.max / 2)
        case 119: model.step(Int.max / 2)
        case 51, 117:
            guard let id = model.selection else { return false }
            model.delete(id)
        default:
            switch e.charactersIgnoringModifiers?.lowercased() {
            case "j": model.shuttle("j")
            case "k": model.shuttle("k")
            case "l": model.shuttle("l")
            case "m":
                if model.userName.trimmingCharacters(in: .whitespaces).isEmpty { model.needsName = true } else { model.addMarker() }
            default: return false
            }
        }
        return true
    }
}
