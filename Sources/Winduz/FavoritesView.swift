import SwiftUI
import WinduzCore

struct FavoritesView: View {
    @State private var query: String = ""
    @State private var favorites: [Favorite] = []
    @State private var selectedIndex: Int = 0
    @State private var pinned: Bool = true
    @FocusState private var fieldFocused: Bool

    let onOpen: (String) -> Void
    let onPinToggle: (Bool) -> Void
    let onEscape: () -> Void

    var filtered: [Favorite] {
        if query.isEmpty { return favorites }
        let q = query.lowercased()
        return favorites.filter {
            $0.name.lowercased().contains(q) || $0.path.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                TextField("Filter", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .onSubmit { openSelected() }
                    .onChange(of: query) { _, _ in selectedIndex = 0 }
                Button(action: {
                    pinned.toggle()
                    onPinToggle(pinned)
                }) {
                    Image(systemName: pinned ? "pin.fill" : "pin.slash")
                }
                .buttonStyle(.borderless)
                .help(pinned ? "Unpin" : "Pin on top")
            }
            .padding(8)
            Divider()
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(filtered.enumerated()), id: \.element.path) { idx, fav in
                        row(fav, selected: idx == selectedIndex)
                            .id(idx)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedIndex = idx
                                onOpen(fav.path)
                            }
                    }
                }
                .listStyle(.plain)
                .onChange(of: selectedIndex) { _, new in
                    withAnimation(nil) { proxy.scrollTo(new, anchor: .center) }
                }
            }
        }
        .frame(minWidth: 280, minHeight: 260)
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow)   { move(-1); return .handled }
        .onKeyPress(.return)    { openSelected(); return .handled }
        .onKeyPress(.escape) {
            if query.isEmpty {
                onEscape()
            } else {
                query = ""
            }
            return .handled
        }
        .onAppear {
            reload()
            fieldFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .winduzFavoritesChanged)) { _ in
            reload()
        }
    }

    @ViewBuilder
    private func row(_ fav: Favorite, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fav.name)
            Text(fav.path)
                .font(.caption)
                .foregroundColor(selected ? .white.opacity(0.8) : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Color.accentColor : Color.clear)
        .foregroundColor(selected ? .white : .primary)
        .cornerRadius(4)
    }

    private func move(_ delta: Int) {
        let count = filtered.count
        guard count > 0 else { selectedIndex = 0; return }
        selectedIndex = max(0, min(count - 1, selectedIndex + delta))
    }

    private func openSelected() {
        guard filtered.indices.contains(selectedIndex) else { return }
        onOpen(filtered[selectedIndex].path)
    }

    private func reload() {
        favorites = Store.shared.load()
        if selectedIndex >= filtered.count { selectedIndex = 0 }
    }
}
