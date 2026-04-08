import AppKit
import Carbon

// MARK: - ShortcutConflictError

/// 단축키 충돌 오류
enum ShortcutConflictError: Error, LocalizedError {
    case conflictWithExistingLayout(name: String)
    case conflictWithSystemShortcut

    var errorDescription: String? {
        switch self {
        case .conflictWithExistingLayout(let name):
            return "'\(name)' 레이아웃과 단축키가 충돌합니다."
        case .conflictWithSystemShortcut:
            return "시스템 단축키와 충돌합니다."
        }
    }
}

// MARK: - KeyboardShortcutManager

/// CGEventTap 기반 전역 키보드 단축키 등록 및 해제 관리
final class KeyboardShortcutManager: @unchecked Sendable {

    // MARK: - Singleton

    nonisolated(unsafe) static let shared = KeyboardShortcutManager()

    // MARK: - Private State

    /// 단축키 -> 레이아웃 매핑 테이블
    private var shortcutMap: [ShortcutBinding: LayoutPreset] = [:]

    /// CGEventTap 참조
    private var eventTap: CFMachPort?

    /// 이벤트 루프 소스
    private var runLoopSource: CFRunLoopSource?

    /// 단축키 활성화 여부
    private var isEnabled: Bool = false

    private init() {}

    // MARK: - Public API

    /// 모든 레이아웃 프리셋의 단축키를 일괄 등록
    func registerShortcuts(from presets: [LayoutPreset]) {
        shortcutMap.removeAll()
        for preset in presets {
            guard let shortcut = preset.shortcut else { continue }
            shortcutMap[shortcut] = preset
        }
        if isEnabled { restartEventTap() }
    }

    /// 이벤트 탭 활성화 (Accessibility 권한 필요)
    /// 탭 생성 실패 시 isEnabled는 false로 유지해 재시도 가능하게 함
    func startListening() {
        guard AXIsProcessTrusted() else { return }
        if isEnabled, eventTap != nil { return }
        tearDownEventTap()
        setupEventTap()
        isEnabled = eventTap != nil
    }

    /// 이벤트 탭 비활성화
    func stopListening() {
        tearDownEventTap()
        isEnabled = false
    }

    /// 단축키 충돌 여부 검사
    func validateShortcut(_ shortcut: ShortcutBinding, excludingLayoutId: UUID?) throws {
        for (existingShortcut, existingLayout) in shortcutMap {
            guard existingLayout.id != excludingLayoutId else { continue }
            if existingShortcut == shortcut {
                throw ShortcutConflictError.conflictWithExistingLayout(name: existingLayout.name)
            }
        }
    }

    // MARK: - Event Tap Setup

    private func setupEventTap() {
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPointer = Unmanaged.passRetained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<KeyboardShortcutManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPointer
        )

        guard let tap = eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func tearDownEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func restartEventTap() {
        tearDownEventTap()
        setupEventTap()
    }

    // MARK: - Event Handling

    private func handleKeyEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        // CGEventFlags.rawValue는 UInt64, NSEvent.ModifierFlags.rawValue는 UInt이므로 변환
        let rawModifiers = UInt(event.flags.rawValue & 0xFFFFFFFF)

        // 정확한 수식키 매칭 (불필요한 플래그 제거 후 비교)
        let relevantFlags: UInt = NSEvent.ModifierFlags.control.rawValue
            | NSEvent.ModifierFlags.option.rawValue
            | NSEvent.ModifierFlags.shift.rawValue
            | NSEvent.ModifierFlags.command.rawValue
        let normalizedModifiers = rawModifiers & relevantFlags

        let normalizedShortcut = ShortcutBinding(keyCode: keyCode, modifiers: normalizedModifiers)

        guard let matchedLayout = shortcutMap.first(where: { $0.key == normalizedShortcut })?.value else {
            return Unmanaged.passRetained(event)
        }

        // 메인 스레드에서 창 이동 수행
        let layoutCopy = matchedLayout
        DispatchQueue.main.async { [weak self] in
            self?.executeSnapAction(for: layoutCopy)
        }

        // 이벤트 소비 (다른 앱으로 전달 안 함)
        return nil
    }

    private func executeSnapAction(for layout: LayoutPreset) {
        guard let window = WindowManager.shared.getFocusedWindow() else { return }
        // Step 2: same policy as `MenuBarController.getActiveScreen` — window screen, then mouse, then main
        let screen = ScreenManager.shared.screenForSnap(with: window)
            ?? ScreenManager.shared.screenContaining(mouseLocation: NSEvent.mouseLocation)
            ?? NSScreen.main
        guard let screen else { return }

        // restore 레이아웃 특수 처리
        if layout.frame.width == 0 && layout.frame.height == 0 && layout.name == BuiltInLayout.restore.localizedName {
            WindowManager.shared.restoreOriginalFrame(for: window)
            return
        }

        if layout.name == BuiltInLayout.moveToMonitor1.localizedName {
            WindowManager.shared.moveFocusedWindowToMonitor(oneBasedIndex: 1)
            return
        }
        if layout.name == BuiltInLayout.moveToMonitor2.localizedName {
            WindowManager.shared.moveFocusedWindowToMonitor(oneBasedIndex: 2)
            return
        }
        if layout.name == BuiltInLayout.moveToMonitor3.localizedName {
            WindowManager.shared.moveFocusedWindowToMonitor(oneBasedIndex: 3)
            return
        }

        // center 레이아웃 특수 처리 (현재 크기 유지, 중앙 배치)
        if layout.frame.width == 0 && layout.frame.height == 0 {
            if let currentFrame = WindowManager.shared.getWindowFrame(window) {
                WindowManager.shared.storeOriginalFrameIfNeeded(for: window)
                let centeredFrame = SnapCalculator.shared.calculateCenterFrame(
                    windowSize: currentFrame.size,
                    on: screen,
                    settings: AppSettings.shared
                )
                WindowManager.shared.setWindowFrame(window, frame: centeredFrame)
            }
            return
        }

        WindowManager.shared.snapWindow(window, to: layout, on: screen)
    }
}
