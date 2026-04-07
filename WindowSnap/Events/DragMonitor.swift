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
    }

    private func handleMouseDragged(event: CGEvent, settings: AppSettings) {
        guard isDragging else { return }

        let mouseLocation = NSEvent.mouseLocation
        // Step 2 (drag): target display is where the cursor is (not focused window)
        guard let screen = ScreenManager.shared.screenContaining(mouseLocation: mouseLocation) else { return }

        let threshold = CGFloat(settings.dragTriggerThreshold)
        let newTriggerZone = SnapCalculator.shared.detectTriggerZone(
            at: mouseLocation,
            on: screen,
            threshold: threshold
        )

        // 트리거 영역 진입/변경 시에만 업데이트 (불필요한 렌더링 방지)
        if newTriggerZone != currentTriggerZone {
            currentTriggerZone = newTriggerZone
            previewScreen = newTriggerZone != nil ? screen : nil
            updatePreview(zone: newTriggerZone, screen: screen, settings: settings)
        }
    }

    private func handleMouseUp(event: CGEvent, settings: AppSettings) {
        let zone = currentTriggerZone
        let screen = previewScreen

        isDragging = false
        currentTriggerZone = nil
        previewScreen = nil

        DispatchQueue.main.async {
            SnapPreviewWindow.shared.hide()
        }

        guard let zone, let screen else { return }

        // 스냅 실행
        executeSnapForZone(zone: zone, screen: screen, settings: settings)
    }

    // MARK: - Preview

    private func updatePreview(zone: SnapTriggerZone?, screen: NSScreen, settings: AppSettings) {
        let snapPreviewEnabled = settings.snapPreviewEnabled
        let halfRatio = settings.halfRatio
        let thirdRatio = settings.thirdRatio
        // NSScreen은 Sendable이 아니므로 스냅 프레임을 미리 계산
        let previewFrame: CGRect? = zone.map { z in
            let previewLayout = z.builtInLayout.makeLayoutPreset(
                halfRatio: halfRatio,
                thirdRatio: thirdRatio
            )
            return SnapCalculator.shared.calculateAbsoluteFrame(
                for: previewLayout,
                on: screen,
                settings: settings
            )
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

    private func executeSnapForZone(zone: SnapTriggerZone, screen: NSScreen, settings: AppSettings) {
        guard let window = WindowManager.shared.getFocusedWindow() else { return }
        let layout = zone.builtInLayout.makeLayoutPreset(
            halfRatio: settings.halfRatio,
            thirdRatio: settings.thirdRatio
        )
        WindowManager.shared.snapWindow(window, to: layout, on: screen)
    }
}
