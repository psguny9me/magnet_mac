import AppKit

// MARK: - AppShortcutAction

/// 창 레이아웃 이외의 앱 기능에 연결되는 전역 단축키 액션
enum AppShortcutAction: String, CaseIterable {
    case saveClipboardImage = "clipboard_save_image"

    var localizedName: String {
        switch self {
        case .saveClipboardImage: return "클립보드 이미지 저장"
        }
    }

    /// 기본 단축키 바인딩 (keyCode는 가상 키 코드)
    var defaultShortcut: ShortcutBinding {
        let ctrlOpt: UInt = NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue
        switch self {
        case .saveClipboardImage:
            return ShortcutBinding(keyCode: 1, modifiers: ctrlOpt) // ⌃⌥S
        }
    }
}
