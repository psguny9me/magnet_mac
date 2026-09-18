import AppKit

// MARK: - DragMonitor

/// CGEventTap 기반 마우스 드래그 이벤트 감지 및 스냅 트리거 처리
final class DragMonitor: @unchecked Sendable {

    // MARK: - Singleton

    nonisolated(unsafe) static let shared = DragMonitor()

    // MARK: - Private State

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isActive: Bool = false

    /// 현재 드래그 중인지 여부
    private var isDragging: Bool = false

    /// 드래그 시작 전 감지된 트리거 영역
    private var currentTriggerZone: SnapTriggerZone?

    /// 미리보기를 표시 중인 화면
    private var previewScreen: NSScreen?

    /// 드래그 중인 창과 드래그 시작 시점 프레임 (창 이동인지 판별용)
    private var dragWindow: AXUIElement?
    private var dragStartFrame: CGRect?

    /// 창 이동으로 확인됐는지 여부. 확인 전에는 스냅 트리거를 적용하지 않는다
    private var isWindowDrag: Bool = false

    /// 창 프레임을 마지막으로 확인한 시각 (AX 호출은 IPC라 매 이벤트마다 하지 않음)
    private var lastFrameCheck: TimeInterval = 0

    /// 창 프레임 재확인 간격 (초)
    private static let frameCheckInterval: TimeInterval = 0.05

    /// 이 거리(pt) 이상 원점이 움직여야 창 이동으로 인정
    private static let moveThreshold: CGFloat = 3

    private init() {
        observeScreenChanges()
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: .screenConfigurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshScreenConfiguration()
        }
    }

    // MARK: - Public API

    /// 드래그 모니터 시작 (Accessibility 권한 필요)
    func startMonitoring() {
        guard AXIsProcessTrusted() else { return }
        if isActive, eventTap != nil { return }
        tearDownEventTap()
        setupEventTap()
        isActive = eventTap != nil
    }

    /// 드래그 모니터 중지
    func stopMonitoring() {
        tearDownEventTap()
        isActive = false
    }

    /// 화면 구성 변경 시 재초기화 (ScreenManager의 screenConfigurationDidChange 알림에 반응)
    func refreshScreenConfiguration() {
        guard isActive else { return }
        stopMonitoring()
        startMonitoring()
    }

    // MARK: - Event Tap Setup

    private func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)

        let selfPointer = Unmanaged.passRetained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<DragMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.handleMouseEvent(type: type, event: event)
                return Unmanaged.passRetained(event)
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

    // MARK: - Event Handling

    private func handleMouseEvent(type: CGEventType, event: CGEvent) {
        // 콜백이 오래 걸리면 시스템이 탭을 끄고 이 이벤트로 알려 준다. 다시 켜지 않으면 드래그 감지가 영구히 멈춘다
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let settings = AppSettings.shared
        guard settings.dragTriggerEnabled else { return }

        switch type {
        case .leftMouseDown:
            handleMouseDown(event: event)
        case .leftMouseDragged:
            handleMouseDragged(event: event, settings: settings)
        case .leftMouseUp:
            handleMouseUp(event: event, settings: settings)
        default:
            break
        }
    }

    private func handleMouseDown(event: CGEvent) {
        isDragging = true
        currentTriggerZone = nil
        previewScreen = nil
        dragWindow = nil
        dragStartFrame = nil
        isWindowDrag = false
        lastFrameCheck = 0
    }

    private func handleMouseDragged(event: CGEvent, settings: AppSettings) {
        guard isDragging else { return }

        // 창을 실제로 끌고 있는 경우에만 트리거를 적용한다.
        // 파일 드래그, 텍스트 선택, 창 리사이즈 중 가장자리에 닿아도 포커스 창이 스냅되지 않도록 한다
        guard confirmWindowDragIfNeeded() else { return }

        let mouseLocation = NSEvent.mouseLocation
        // Step 2 (drag): target display is where the cursor is (not focused window)
        guard let screen = ScreenManager.shared.screenContaining(mouseLocation: mouseLocation) else { return }

        let threshold = CGFloat(settings.dragTriggerThreshold)
        let newTriggerZone = SnapCalculator.shared.detectTriggerZone(
            at: mouseLocation,
            on: screen,
            threshold: threshold
        )

        let previewTarget = newTriggerZone != nil ? screen : nil
        let screenChangedWhileInZone: Bool = {
            guard newTriggerZone != nil, let previous = previewScreen else { return false }
            return previous.frame != screen.frame
        }()

        // 트리거 종류가 바뀌거나, 같은 종류라도 커서가 다른 모니터로 옮겨진 경우 갱신
        if newTriggerZone != currentTriggerZone || screenChangedWhileInZone {
            currentTriggerZone = newTriggerZone
            previewScreen = previewTarget
            updatePreview(zone: newTriggerZone, screen: screen, settings: settings)
        }
    }

    private func handleMouseUp(event: CGEvent, settings: AppSettings) {
        let zone = currentTriggerZone
        let screen = previewScreen
        let window = isWindowDrag ? dragWindow : nil

        isDragging = false
        currentTriggerZone = nil
        previewScreen = nil
        dragWindow = nil
        dragStartFrame = nil
        isWindowDrag = false

        DispatchQueue.main.async { [weak self] in
            SnapPreviewWindow.shared.hide()
            guard let self, let zone, let screen, let window else { return }
            let snapSettings = AppSettings.shared
            self.executeSnapForZone(zone: zone, screen: screen, settings: snapSettings, window: window)
        }
    }

    // MARK: - Window Drag Detection

    /// 포커스 창의 원점이 움직였고 크기는 그대로면 창 이동으로 판정한다 (리사이즈는 크기가 바뀌므로 제외).
    /// 한 번 확인되면 드래그가 끝날 때까지 다시 검사하지 않는다
    private func confirmWindowDragIfNeeded() -> Bool {
        if isWindowDrag { return true }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFrameCheck >= Self.frameCheckInterval else { return false }
        lastFrameCheck = now

        // 첫 드래그 이벤트에서 창을 붙잡는다 (mouseDown 직후에는 포커스 전환이 끝나지 않았을 수 있음)
        if dragWindow == nil {
            guard let window = WindowManager.shared.getFocusedWindow(),
                  let frame = WindowManager.shared.getWindowFrame(window) else { return false }
            dragWindow = window
            dragStartFrame = frame
            return false
        }

        guard let window = dragWindow,
              let startFrame = dragStartFrame,
              let currentFrame = WindowManager.shared.getWindowFrame(window) else { return false }

        let moved = abs(currentFrame.origin.x - startFrame.origin.x) >= Self.moveThreshold
            || abs(currentFrame.origin.y - startFrame.origin.y) >= Self.moveThreshold
        let sameSize = abs(currentFrame.width - startFrame.width) < 1
            && abs(currentFrame.height - startFrame.height) < 1

        if moved && sameSize {
            isWindowDrag = true
        }
        return isWindowDrag
    }

    // MARK: - Preview

    private func updatePreview(zone: SnapTriggerZone?, screen: NSScreen, settings: AppSettings) {
        let snapPreviewEnabled = settings.snapPreviewEnabled
        let halfRatio = settings.halfRatio
        let thirdRatio = settings.thirdRatio
        // NSScreen은 Sendable이 아니므로 스냅 프레임을 미리 계산
        // calculateAbsoluteFrame은 AX(좌상단) 좌표를 돌려주고, NSWindow.setFrame은 좌하단 글로벌 좌표를 받으므로 변환한다
        let previewFrame: CGRect? = zone.map { z in
            let previewLayout = z.builtInLayout.makeLayoutPreset(
                halfRatio: halfRatio,
                thirdRatio: thirdRatio
            )
            let axFrame = SnapCalculator.shared.calculateAbsoluteFrame(
                for: previewLayout,
                on: screen,
                settings: settings
            )
            return SnapCalculator.shared.convertAXFrameToBottomLeftGlobal(axFrame)
        }
        DispatchQueue.main.async {
            guard let frame = previewFrame, snapPreviewEnabled else {
                SnapPreviewWindow.shared.hide()
                return
            }
            SnapPreviewWindow.shared.show(frame: frame)
        }
    }

    // MARK: - Snap Execution

    private func executeSnapForZone(
        zone: SnapTriggerZone,
        screen: NSScreen,
        settings: AppSettings,
        window: AXUIElement
    ) {
        let layout = zone.builtInLayout.makeLayoutPreset(
            halfRatio: settings.halfRatio,
            thirdRatio: settings.thirdRatio
        )
        WindowManager.shared.snapWindow(window, to: layout, on: screen)
    }
}
