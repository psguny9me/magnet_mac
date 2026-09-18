import SwiftUI

// MARK: - ShortcutRowModel

/// 단축키 설정 행 데이터 모델
struct ShortcutRowModel: Identifiable {
    let id: String
    let name: String
    var shortcut: ShortcutBinding?
}

// MARK: - ShortcutsView

/// 단축키 설정 탭 뷰
struct ShortcutsView: View {

    @State private var settings = AppSettings.shared
    @State private var isRecording: String? = nil
    @State private var conflictMessage: String? = nil

    var shortcutRows: [ShortcutRowModel] {
        let layoutRows = BuiltInLayout.allCases.map { layout in
            let currentShortcut = settings.shortcutBindings[layout.rawValue] ?? layout.defaultShortcut
            return ShortcutRowModel(id: layout.rawValue, name: layout.localizedName, shortcut: currentShortcut)
        }
        let actionRows = AppShortcutAction.allCases.map { action in
            let currentShortcut = settings.shortcutBindings[action.rawValue] ?? action.defaultShortcut
            return ShortcutRowModel(id: action.rawValue, name: action.localizedName, shortcut: currentShortcut)
        }
        return layoutRows + actionRows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(shortcutRows) { row in
                ShortcutRowView(
                    row: row,
                    isRecording: isRecording == row.id,
                    onStartRecording: { isRecording = row.id },
                    onBindShortcut: { newShortcut in
                        bindShortcut(newShortcut, for: row.id)
                    },
                    onCancelRecording: { isRecording = nil },
                    onClearShortcut: {
                        clearShortcut(for: row.id)
                    }
                )
            }

            if let conflict = conflictMessage {
                Text(conflict)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            HStack {
                Spacer()
                Button("기본값으로 초기화") {
                    resetAllShortcuts()
                }
                .padding()
            }
        }
        .onTapGesture { isRecording = nil }
    }

    /// - Parameter layoutId: 행의 키. 내장 레이아웃은 `BuiltInLayout.rawValue`, 액션은 `AppShortcutAction.rawValue`이며
    ///   `LayoutPreset.bindingKey`와 같은 값이라 자기 자신과의 충돌을 제외할 수 있다
    private func bindShortcut(_ shortcut: ShortcutBinding, for layoutId: String) {
        do {
            try KeyboardShortcutManager.shared.validateShortcut(shortcut, excludingKey: layoutId)
            settings.shortcutBindings[layoutId] = shortcut
            conflictMessage = nil
            reloadShortcuts()
        } catch {
            conflictMessage = error.localizedDescription
        }
        isRecording = nil
    }

    private func clearShortcut(for layoutId: String) {
        settings.shortcutBindings[layoutId] = nil
        reloadShortcuts()
    }

    private func resetAllShortcuts() {
        settings.shortcutBindings = [:]
        reloadShortcuts()
    }

    private func reloadShortcuts() {
        let presets = settings.makeBuiltInPresets() + settings.customLayouts
        KeyboardShortcutManager.shared.registerShortcuts(from: presets)
        KeyboardShortcutManager.shared.registerActionShortcuts(settings.makeActionShortcutMap())
        MenuBarController.shared.rebuildMenu()
    }
}

// MARK: - ShortcutRowView

/// 단축키 목록의 각 행 뷰
private struct ShortcutRowView: View {

    let row: ShortcutRowModel
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onBindShortcut: (ShortcutBinding) -> Void
    let onCancelRecording: () -> Void
    let onClearShortcut: () -> Void

    var body: some View {
        HStack {
            Text(row.name)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isRecording {
                ShortcutRecorderView(onRecord: onBindShortcut, onCancel: onCancelRecording)
                    .frame(width: 150)
            } else {
                shortcutLabel
                    .onTapGesture { onStartRecording() }
            }

            Button(action: onClearShortcut) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(row.shortcut != nil ? 1 : 0)
        }
        .padding(.vertical, 2)
    }

    private var shortcutLabel: some View {
        Group {
            if let shortcut = row.shortcut {
                Text(shortcut.displayString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text("없음")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
            }
        }
        .frame(width: 150, alignment: .center)
    }
}

// MARK: - ShortcutRecorderView

/// 키보드 단축키를 녹화하는 커스텀 뷰 (NSViewRepresentable)
struct ShortcutRecorderView: NSViewRepresentable {

    let onRecord: (ShortcutBinding) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.onRecord = onRecord
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {}
}

// MARK: - ShortcutRecorderNSView

/// 실제 키 입력을 감지하는 NSView
final class ShortcutRecorderNSView: NSView {

    var onRecord: ((ShortcutBinding) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let relevant: UInt = NSEvent.ModifierFlags.control.rawValue
            | NSEvent.ModifierFlags.option.rawValue
            | NSEvent.ModifierFlags.shift.rawValue
            | NSEvent.ModifierFlags.command.rawValue
        let modifiers = event.modifierFlags.rawValue & relevant
        // 수식키 없는 ⎋는 녹화 취소, 그 외 수식키 없는 키는 무시
        if modifiers == 0 {
            if event.keyCode == 53 { onCancel?() }
            return
        }
        let shortcut = ShortcutBinding(keyCode: event.keyCode, modifiers: modifiers)
        onRecord?(shortcut)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.selectedControlColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
        let text = "단축키 입력 (⎋ 취소)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.selectedControlTextColor,
            .font: NSFont.systemFont(ofSize: 12)
        ]
        let size = text.size(withAttributes: attrs)
        let origin = CGPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        text.draw(at: origin, withAttributes: attrs)
    }
}
