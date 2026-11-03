import AVKit
import MarkerCore
import SwiftUI
import UniformTypeIdentifiers

/// AVPlayerView without its own controls: the timeline and the keyboard drive playback.
struct VideoView: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = player
        v.controlsStyle = .none
        v.videoGravity = .resizeAspect
        return v
    }
    func updateNSView(_ v: AVPlayerView, context: Context) {}
}

/// Lays children out left to right and wraps to the next line when the width is used up.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { y += line + lineSpacing; x = 0; line = 0 }
            x += size.width + spacing
            line = max(line, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { y += line + lineSpacing; x = bounds.minX; line = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: PlayerModel
    @ObservedObject private var settings = AppSettings.shared
    @State private var askName = false
    @State private var nameDraft = ""
    private var t: Theme { settings.theme }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                topBar
                if model.info == nil {
                    dropHint
                } else {
                    VideoView(player: model.player).background(Color.black)
                    VStack(spacing: 8) {
                        OverviewBar(model: model, theme: t).frame(height: 40)
                        DetailTimeline(model: model, theme: t).frame(height: 84)
                        keyHelp
                    }
                    .padding(12)
                    .background(t.background)
                }
            }
            if model.info != nil {
                Rectangle().fill(t.line).frame(width: 1)
                MarkerList(model: model, theme: t).frame(width: 330)
            }
        }
        .background(t.background)
        .environment(\.colorScheme, settings.dark ? .dark : .light)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            _ = providers.first?.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in await model.open(url) } }
            }
            return true
        }
        .onChange(of: model.needsName) { need in
            if need { nameDraft = model.userName; askName = true }
        }
        .sheet(isPresented: $askName) { nameSheet }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Text(model.url?.deletingPathExtension().lastPathComponent ?? "MarkTheRoughcut")
                .font(.mono(13)).foregroundColor(t.muted).lineLimit(1).truncationMode(.middle)
            Spacer()
            if let notice = model.notice {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundColor(t.warning)
                    Text(notice).font(.mono(11)).foregroundColor(t.text).lineLimit(2)
                    Button { model.notice = nil } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)).foregroundColor(t.faint) }
                        .buttonStyle(.plain).accessibilityLabel(Text("Close"))
                }
            }
            Text(model.tc).font(.mono(22, semibold: true)).foregroundColor(t.text).monospacedDigit()
        }
        .padding(.horizontal, 16).frame(height: 48)
        .background(t.background)
    }

    private var dropHint: some View {
        VStack(spacing: 16) {
            Image(systemName: "film").font(.system(size: 40, weight: .light)).foregroundColor(t.faint)
            Text("Drop a video here").font(.mono(15)).foregroundColor(t.text)
            Button("Open Video…") { openVideo(model) }.buttonStyle(FerryButtonStyle(theme: t, primary: true))
            Text("MOV and MP4 – everything QuickTime Player plays.").font(.mono(11)).foregroundColor(t.faint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var keyHelp: some View {
        // wraps instead of widening the window (German labels are longer)
        FlowLayout(spacing: 14, lineSpacing: 4) {
            ForEach([("Space", "Play"), ("J K L", "Shuttle"), ("← →", "Frame"), ("⇧← →", "Second"), ("↑ ↓", "Zoom"),
                     ("M", "Marker"), ("⌥← →", "Jump")], id: \.0) { key, what in
                HStack(spacing: 5) {
                    Text(LocalizedStringKey(key)).font(.mono(10, semibold: true)).foregroundColor(t.muted)
                    Text(LocalizedStringKey(what)).font(.mono(10)).foregroundColor(t.faint)
                }
                .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your name").font(.mono(14, semibold: true)).foregroundColor(t.text)
            Text("It appears with every marker in Avid, so the editor knows who wrote it.")
                .font(.mono(12)).foregroundColor(t.muted).fixedSize(horizontal: false, vertical: true)
            TextField("Name", text: $nameDraft).textFieldStyle(.roundedBorder).font(.mono(13))
                .onSubmit(saveName)
            HStack {
                Spacer()
                if !model.userName.isEmpty {
                    Button("Cancel") { askName = false; model.needsName = false; model.pendingMarker = false }
                        .buttonStyle(FerryButtonStyle(theme: t)).keyboardShortcut(.cancelAction)
                }
                Button("OK", action: saveName).buttonStyle(FerryButtonStyle(theme: t, primary: true)).keyboardShortcut(.defaultAction)
                    .disabled(nameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24).frame(width: 380).background(t.background).environment(\.colorScheme, settings.dark ? .dark : .light)
    }

    private func saveName() {
        let name = nameDraft.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        model.userName = name
        askName = false
        model.needsName = false
        if model.pendingMarker {
            model.pendingMarker = false
            model.addMarker()
        }
    }
}

@MainActor
func openVideo(_ model: PlayerModel) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.movie, .video, .quickTimeMovie, .mpeg4Movie]
    panel.canChooseDirectories = false
    if panel.runModal() == .OK, let url = panel.url {
        Task { await model.open(url) }
    }
}

@MainActor
func importMarkers(_ model: PlayerModel) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.plainText, .text]
    panel.message = String(localized: "Choose a marker list exported from Avid (Markers window → Export Markers).")
    if panel.runModal() == .OK, let url = panel.url { model.importMarkers(from: url) }
}

@MainActor
func exportMarkers(_ model: PlayerModel) {
    guard let data = model.exportData() else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.plainText]
    panel.nameFieldStringValue = "\(model.url?.deletingPathExtension().lastPathComponent ?? "Markers") Markers.txt"
    panel.message = String(localized: "In Avid: Markers window → Import Markers.")
    if panel.runModal() == .OK, let url = panel.url {
        do { try data.write(to: url, options: .atomic) } catch {
            model.notice = String(localized: "The marker list could not be saved: \(error.localizedDescription)")
        }
    }
}
