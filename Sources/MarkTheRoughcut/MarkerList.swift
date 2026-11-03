import MarkerCore
import SwiftUI

/// All markers in time order. Click jumps there; the comment is edited right in the list.
struct MarkerList: View {
    @ObservedObject var model: PlayerModel
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // the name that goes into Avid with every new marker – always visible, editable
            HStack(spacing: 8) {
                Image(systemName: "person").font(.system(size: 11)).foregroundColor(theme.faint)
                Text(model.userName.isEmpty ? String(localized: "No name yet") : model.userName)
                    .font(.mono(12, semibold: !model.userName.isEmpty))
                    .foregroundColor(model.userName.isEmpty ? theme.faint : theme.text)
                    .lineLimit(1).truncationMode(.tail)
                Spacer()
                Button { model.needsName = true } label: {
                    Image(systemName: "pencil").font(.system(size: 11)).foregroundColor(theme.muted)
                        .frame(width: 22, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(Text("Change name"))
                .accessibilityLabel(Text("Change name"))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            Rectangle().fill(theme.line).frame(height: 1)
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
                // while typing: a quiet input box (lighter surface, darker outline)
                .padding(.horizontal, focused ? 8 : 0)
                .padding(.vertical, focused ? 6 : 0)
                .background(RoundedRectangle(cornerRadius: 5).fill(focused ? theme.field : .clear))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(focused ? theme.fieldLine : .clear, lineWidth: 1))
                .animation(.easeOut(duration: 0.12), value: focused)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(selected ? theme.selection : Color.clear)
        // selected: a thin bar in the marker's colour instead of a darker grey
        .overlay(alignment: .leading) { if selected { Rectangle().fill(marker.color.color).frame(width: 3) } }
        .contentShape(Rectangle())
        .onTapGesture { model.jump(to: marker) }
        .onChange(of: focused) { f in if f { model.jump(to: marker) } }
        .onAppear { if model.editing == marker.id { focused = true; model.editing = nil } }
        .onChange(of: model.editing) { id in if id == marker.id { focused = true; model.editing = nil } }
    }
}
