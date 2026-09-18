import AppKit
import Carbon

// MARK: - ShortcutConflictError

/// 단축키 충돌 오류
enum ShortcutConflictError: Error, LocalizedError {
    case conflictWithExistingLayout(name: String)
    case conflictWithSystemShortcut
    case insufficientModifiers

    var errorDescription: String? {
        switch self {
        case .conflictWithExistingLayout(let name):
            return "'\(name)' 레이아웃과 단축키가 충돌합니다."
        case .conflictWithSystemShortcut:
            return "macOS 시스템 단축키와 충돌하므로 등록할 수 없습니다."
        case .insufficientModifiers:
            return "⌃(control) 또는 ⌥(option)을 포함해야 합니다. ⌘·⇧만 쓰는 조합은 다른 앱의 단축키를 가로챕니다."
        }
    }
}

// MARK: - KeyboardShortcutManager

/// CGEventTap 기반 전역 키보드 단축키 등록 및 해제 관리
///
/// 이벤트 탭은 능동 모드(`.defaultTap`)라 콜백이 막히면 시스템 전체 키 입력이 지연된다.
/// 그래서 메인 런루프가 아니라 전용 스레드의 런루프에 탭을 붙이고, 실제 창 조작만 메인 스레드로 넘긴다.
final class KeyboardShortcutManager: @unchecked Sendable {

    // MARK: - Singleton

    nonisolated(unsafe) static let shared = KeyboardShortcutManager()

    // MARK: - Private State

    /// 매핑 테이블 보호용 락 (탭 스레드에서 읽고 메인 스레드에서 갱신)
    private let mapLock = NSLock()

    /// 단축키 -> 레이아웃 매핑 테이블 (mapLock으로 보호)
    private var shortcutMap: [ShortcutBinding: LayoutPreset] = [:]

    /// 단축키 -> 앱 액션(클립보드 이미지 저장 등) 매핑 테이블 (mapLock으로 보호)
    private var actionMap: [ShortcutBinding: AppShortcutAction] = [:]

    /// CGEventTap 참조
    private var eventTap: CFMachPort?

    /// 이벤트 루프 소스
    private var runLoopSource: CFRunLoopSource?

    /// 탭 전용 스레드와 그 런루프
    private var tapThread: Thread?
    private var tapRunLoop: CFRunLoop?

    /// 단축키 활성화 여부
    private var isEnabled: Bool = false

    private init() {}

    // MARK: - Public API

    /// 모든 레이아웃 프리셋의 단축키를 일괄 등록 (탭 재생성 없이 매핑만 교체)
    func registerShortcuts(from presets: [LayoutPreset]) {
        var newMap: [ShortcutBinding: LayoutPreset] = [:]
        for preset in presets {
            guard let shortcut = preset.shortcut else { continue }
            newMap[shortcut] = preset
        }
        mapLock.withLock { shortcutMap = newMap }
    }

    /// 앱 액션 단축키를 일괄 등록 (탭 재생성 없이 매핑만 교체)
    func registerActionShortcuts(_ map: [ShortcutBinding: AppShortcutAction]) {
        mapLock.withLock { actionMap = map }
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

    /// 단축키 충돌·유효성 검사
    /// - Parameters:
    ///   - shortcut: 검사할 단축키
    ///   - excludingKey: 지금 편집 중인 항목의 키(`LayoutPreset.bindingKey` 또는 `AppShortcutAction.rawValue`).
    ///     같은 항목에 같은 단축키를 다시 넣는 경우를 충돌로 보지 않기 위해 제외한다
    func validateShortcut(_ shortcut: ShortcutBinding, excludingKey: String? = nil) throws {
        try Self.validateAgainstSystem(shortcut)

        let (layouts, actions) = mapLock.withLock { (shortcutMap, actionMap) }
        for (existingShortcut, existingLayout) in layouts where existingShortcut == shortcut {
            guard existingLayout.bindingKey != excludingKey else { continue }
            throw ShortcutConflictError.conflictWithExistingLayout(name: existingLayout.name)
        }
        for (existingShortcut, action) in actions where existingShortcut == shortcut {
            guard action.rawValue != excludingKey else { continue }
            throw ShortcutConflictError.conflictWithExistingLayout(name: action.localizedName)
        }
    }

    // MARK: - System Shortcut Rules

    /// 탭이 `.headInsertEventTap`이라 등록된 조합은 모든 앱에서 소비된다.
    /// ⌘·⇧만 쓰는 조합(⌘Q, ⌘C, ⌘Tab, ⌘Space 등)을 막고, ⌃/⌥가 있어도 위험한 시스템 조합은 별도로 거른다
    static func validateAgainstSystem(_ shortcut: ShortcutBinding) throws {
        let flags = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)
        guard flags.contains(.control) || flags.contains(.option) else {
            throw ShortcutConflictError.insufficientModifiers
        }
        if reservedSystemShortcuts.contains(shortcut) {
            throw ShortcutConflictError.conflictWithSystemShortcut
        }
    }

    /// ⌃/⌥를 포함하지만 macOS가 예약한 조합
    private static let reservedSystemShortcuts: Set<ShortcutBinding> = {
        let ctrl = NSEvent.ModifierFlags.control.rawValue
        let opt = NSEvent.ModifierFlags.option.rawValue
        let cmd = NSEvent.ModifierFlags.command.rawValue
        let shift = NSEvent.ModifierFlags.shift.rawValue
        var set: Set<ShortcutBinding> = [
            ShortcutBinding(keyCode: 53, modifiers: cmd | opt),          // ⌘⌥⎋ 강제 종료
            ShortcutBinding(keyCode: 53, modifiers: cmd | opt | shift),  // ⌘⌥⇧⎋ 즉시 강제 종료
            ShortcutBinding(keyCode: 12, modifiers: cmd | ctrl),         // ⌃⌘Q 화면 잠금
            ShortcutBinding(keyCode: 49, modifiers: ctrl),               // ⌃Space 입력 소스 전환
            ShortcutBinding(keyCode: 49, modifiers: ctrl | opt),         // ⌃⌥Space 입력 소스 전환
            ShortcutBinding(keyCode: 2,  modifiers: cmd | opt),          // ⌘⌥D Dock 가리기
            ShortcutBinding(keyCode: 3,  modifiers: cmd | ctrl),         // ⌃⌘F 전체 화면
            ShortcutBinding(keyCode: 47, modifiers: cmd | opt),          // ⌘⌥. 기타
        ]
        // ⌃←/→/↑/↓: Mission Control·Spaces 전환
        for arrow: UInt16 in [123, 124, 125, 126] {
            set.insert(ShortcutBinding(keyCode: arrow, modifiers: ctrl))
        }
        return set
    }()

    // MARK: - Event Tap Setup

    /// 탭과 런루프 소스를 만든 뒤 전용 스레드에서 런루프를 돌린다.
    /// 탭 생성은 호출 스레드에서 동기적으로 하므로 성공 여부를 즉시 알 수 있다
    private func setupEventTap() {
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        // 싱글턴이라 수명이 앱과 같으므로 retain 없이 포인터만 넘긴다 (재생성 시 누수 방지)
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

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

        guard let tap = eventTap,
              let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            eventTap = nil
            return
        }
        runLoopSource = source

        // 스레드가 런루프를 확보할 때까지 잠깐 기다려 tapRunLoop를 확정한다 (stop 시 레이스 방지)
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in
            let runLoop = CFRunLoopGetCurrent()
            self.tapRunLoop = runLoop
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = "com.windowsnap.keyboard-event-tap"
        thread.qualityOfService = .userInteractive
        tapThread = thread
        thread.start()
        ready.wait()
    }

    private func tearDownEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoop = tapRunLoop {
            if let source = runLoopSource {
                CFRunLoopRemoveSource(runLoop, source, .commonModes)
            }
            CFRunLoopStop(runLoop)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
        tapRunLoop = nil
        tapThread = nil
    }

    // MARK: - Event Handling (탭 전용 스레드에서 실행)

    private func handleKeyEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // 콜백이 오래 걸리면 시스템이 탭을 끄고 이 이벤트로 알려 준다. 다시 켜지 않으면 단축키가 영구히 멈춘다
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }
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

        let (matchedAction, matchedLayout) = mapLock.withLock {
            (actionMap[normalizedShortcut], shortcutMap[normalizedShortcut])
        }

        // 앱 액션 단축키 우선 처리
        if let matchedAction {
            DispatchQueue.main.async {
                switch matchedAction {
                case .saveClipboardImage:
                    ClipboardImageSaver.shared.saveClipboardImage()
                }
            }
            // 이벤트 소비 (다른 앱으로 전달 안 함)
            return nil
        }

        guard let matchedLayout else {
            return Unmanaged.passRetained(event)
        }

        // 메인 스레드에서 창 이동 수행
        DispatchQueue.main.async { [weak self] in
            self?.executeSnapAction(for: matchedLayout)
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
