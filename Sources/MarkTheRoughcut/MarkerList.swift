import MarkerCore
import SwiftUI

/// All markers in time order. Click jumps there; the comment is edited right in the list.
struct MarkerList: View {
    @ObservedObject var model: PlayerModel
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("MARKERS").font(.mono(11)).tracking(1.5).foregroundColor(theme.muted)
                Spacer()
                Text("\(model.markers.count)").font(.mono(11)).foregroundColor(theme.faint)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Rectangle().fill(theme.line).frame(height: 1)
            if model.markers.isEmpty {
                Text("Press M to set a marker at the playhead.")
                    .font(.mono(12)).foregroundColor(theme.faint).padding(14)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // bound by id, not by position: inserting a marker must never redirect a text field
                            ForEach(model.markers) { m in
                                MarkerRow(marker: model.binding(for: m.id, fallback: m), model: model, theme: theme)
                                Rectangle().fill(theme.line.opacity(0.6)).frame(height: 1)
                            }
                        }
                    }
                    .onChange(of: model.selection) { id in
                        if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
            }
        }
        .background(theme.panel)
    }
}

struct MarkerRow: View {
    @Binding var marker: Marker
    @ObservedObject var model: PlayerModel
    let theme: Theme
    @FocusState private var focused: Bool

    var body: some View {
        let selected = model.selection == marker.id
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(MarkerColor.allCases, id: \.self) { c in
                        Button { marker.color = c; model.defaultColor = c.rawValue } label: { Text(c.label) }
                    }
                } label: {
                    Circle().fill(marker.color.color).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(theme.line, lineWidth: 1))
                }
                // button style keeps the drawn dot (the borderless style drops custom shapes)
                .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                .help(Text("Colour"))
                Text(model.info.map { $0.format.string(marker.frame) } ?? "").font(.mono(12, semibold: true)).foregroundColor(theme.text)
                if marker.duration > 1 {
                    Text("+\(marker.duration)f").font(.mono(10)).foregroundColor(theme.faint)
                }
                Spacer()
                Text(marker.user).font(.mono(10)).foregroundColor(theme.faint).lineLimit(1)
                Button { model.delete(marker.id) } label: {
                    Image(systemName: "trash").font(.system(size: 10)).foregroundColor(theme.faint)
                }
                .buttonStyle(.plain)
                .help(Text("Delete marker"))
                .accessibilityLabel(Text("Delete marker"))
            }
            TextField("Comment", text: $marker.comment, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.mono(12))
                .foregroundColor(theme.text)
                .lineLimit(1...8)
                .focused($focused)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(selected ? theme.text.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { model.jump(to: marker) }
        .onChange(of: focused) { f in if f { model.jump(to: marker) } }
        .onAppear { if model.editing == marker.id { focused = true; model.editing = nil } }
        .onChange(of: model.editing) { id in if id == marker.id { focused = true; model.editing = nil } }
    }
}
