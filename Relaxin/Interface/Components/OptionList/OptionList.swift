import SwiftUI

struct OptionList<Action: Hashable>: View {
    let entries: [OptionListItem<Action>]
    let preferredSelection: Action?
    let secondaryActions: Set<Action>
    let shareItems: [Action: URL]
    let loadingActions: Set<Action>
    let style: OptionListStyle
    let isVolumeButtonInputEnabled: Bool
    let onSelectionChange: (Action) -> Void
    let onSelect: (Action) -> Void
    @State private var selected: Action?
    @State private var pendingAction: Task<Void, Never>?
    @State private var sharePresentation: SharePresentation?

    private var selectedID: Action? {
        guard let selected, entries.contains(where: { $0.id == selected }) else {
            return defaultSelection
        }
        return selected
    }

    private var defaultSelection: Action? {
        if let preferredSelection, entries.contains(where: { $0.id == preferredSelection }) {
            return preferredSelection
        }
        return entries.first?.id
    }

    init(
        entries: [OptionListItem<Action>],
        preferredSelection: Action? = nil,
        secondaryActions: Set<Action> = [],
        shareItems: [Action: URL] = [:],
        loadingActions: Set<Action> = [],
        style: OptionListStyle = .standard,
        isVolumeButtonInputEnabled: Bool = true,
        onSelectionChange: @escaping (Action) -> Void = { _ in },
        onSelect: @escaping (Action) -> Void
    ) {
        self.entries = entries
        self.preferredSelection = preferredSelection
        self.secondaryActions = secondaryActions
        self.shareItems = shareItems
        self.loadingActions = loadingActions
        self.style = style
        self.isVolumeButtonInputEnabled = isVolumeButtonInputEnabled
        self.onSelectionChange = onSelectionChange
        self.onSelect = onSelect
        _selected = State(
            initialValue: preferredSelection.flatMap { preferred in
                entries.contains(where: { $0.id == preferred }) ? preferred : nil
            } ?? entries.first?.id
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(entries) { entry in
                let isSecondary = secondaryActions.contains(entry.id)
                let isSelected = entry.id == selectedID
                let isLoading = loadingActions.contains(entry.id)

                Button {
                    activate(entry.id)
                } label: {
                    label(for: entry, isSelected: isSelected, isSecondary: isSecondary)
                }
                .buttonStyle(
                    RowButtonStyle(
                        isSelected: isSelected,
                        isLoading: isLoading,
                        accent: style.accent,
                        onPress: { select(entry.id) }
                    )
                )
                .disabled(isLoading)
                .id(entry.id)
            }
        }
        .font(Theme.font)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isVolumeButtonInputEnabled, sharePresentation == nil {
                VolumeButtonInput(
                    onTap: moveSelection,
                    onLongPress: activateSelection
                )
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            }
        }
        .onChange(of: entries.map(\.id)) { _ in
            select(defaultSelection)
        }
        .onChange(of: preferredSelection) { _ in
            select(defaultSelection)
        }
        .onAppear {
            if let selectedID {
                onSelectionChange(selectedID)
            }
        }
        .onDisappear {
            pendingAction?.cancel()
        }
        .sheet(item: $sharePresentation) { presentation in
            ShareSheet(url: presentation.url)
        }
    }

    private func label(
        for entry: OptionListItem<Action>,
        isSelected: Bool,
        isSecondary: Bool
    ) -> some View {
        Text(entry.title)
            .fontWeight(isSelected ? .bold : .regular)
            .foregroundStyle(
                isSelected
                    ? style.accent
                    : isSecondary ? style.secondaryForeground : style.foreground
            )
            .fixedSize(horizontal: true, vertical: false)
    }

    private func activate(_ action: Action) {
        select(action)
        pendingAction?.cancel()
        if let url = shareItems[action] {
            sharePresentation = SharePresentation(url: url)
            return
        }

        pendingAction = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return
            }
            guard selected == action else { return }
            onSelect(action)
        }
    }

    private func moveSelection(_ direction: VolumeButtonDirection) {
        guard
            let selectedID,
            let selectedIndex = entries.firstIndex(where: { $0.id == selectedID })
        else {
            return
        }

        let targetIndex = switch direction {
        case .up:
            max(entries.startIndex, selectedIndex - 1)
        case .down:
            min(entries.index(before: entries.endIndex), selectedIndex + 1)
        }
        select(entries[targetIndex].id)
    }

    private func activateSelection() {
        guard
            let selectedID,
            !loadingActions.contains(selectedID)
        else {
            return
        }
        activate(selectedID)
    }

    private func select(_ id: Action?) {
        guard selected != id else { return }
        withTransaction(Transaction(animation: nil)) {
            selected = id
        }
        if let id {
            onSelectionChange(id)
        }
    }
}
