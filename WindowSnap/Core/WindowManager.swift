import AppKit
import ApplicationServices

// MARK: - WindowManager

/// AXUIElement API를 이용한 창 이동/리사이즈 핵심 제어 클래스
final class WindowManager {

    // MARK: - Singleton

    nonisolated(unsafe) static let shared = WindowManager()

    // MARK: - Private State

    /// 스냅 전 원본 프레임 저장소 (복원 기능용)
    private var originalFrames: [CGWindowID: CGRect] = [:]

    private init() {}

    // MARK: - Public API

    /// 현재 포커스된 창의 AXUIElement를 반환
    func getFocusedWindow() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )
        guard result == .success, let window = focusedWindow else { return nil }
        return (window as! AXUIElement)
    }

    /// 포커스 창을 `NSScreen.screens` 기준 N번째 모니터(없으면 마지막) 가용 영역 중앙으로 이동
    func moveFocusedWindowToMonitor(oneBasedIndex: Int) {
        guard let window = getFocusedWindow(),
              let frame = getWindowFrame(window),
              let screen = ScreenManager.shared.effectiveScreen(forOneBasedIndex: oneBasedIndex) else { return }
        let settings = AppSettings.shared
        storeOriginalFrameIfNeeded(for: window)
        let centeredFrame = SnapCalculator.shared.calculateCenterFrame(
            windowSize: frame.size,
            on: screen,
            settings: settings
        )
        setWindowFrame(window, frame: centeredFrame)
    }

    /// 창을 지정된 레이아웃 프리셋과 화면 프레임으로 스냅
    func snapWindow(_ window: AXUIElement, to layout: LayoutPreset, on screen: NSScreen) {
        let targetFrame = SnapCalculator.shared.calculateAbsoluteFrame(
            for: layout,
            on: screen,
            settings: AppSettings.shared
        )
        storeOriginalFrameIfNeeded(for: window)
        setWindowFrame(window, frame: targetFrame)
    }

    /// 창을 지정된 절대 프레임으로 이동/리사이즈
    func setWindowFrame(_ window: AXUIElement, frame: CGRect) {
        var position = frame.origin
        var size = frame.size
        guard let posValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }

    /// 창의 현재 프레임(CGRect)을 읽어서 반환
    func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        guard let position = getWindowPosition(window),
              let size = getWindowSize(window) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// 스냅 전 원본 프레임을 저장 (아직 저장되지 않은 경우에만)
    func storeOriginalFrameIfNeeded(for window: AXUIElement) {
        guard let windowID = getWindowID(window),
              originalFrames[windowID] == nil,
              let frame = getWindowFrame(window) else { return }
        originalFrames[windowID] = frame
    }

    /// 저장된 원본 프레임으로 창을 복원
    func restoreOriginalFrame(for window: AXUIElement) {
        guard let windowID = getWindowID(window),
              let originalFrame = originalFrames[windowID] else { return }
        setWindowFrame(window, frame: originalFrame)
        originalFrames.removeValue(forKey: windowID)
    }

    /// 저장된 원본 프레임을 명시적으로 지움 (복원 기록 초기화)
    func clearOriginalFrame(for windowID: CGWindowID) {
        originalFrames.removeValue(forKey: windowID)
    }

    // MARK: - Private Helpers

    private func getWindowPosition(_ window: AXUIElement) -> CGPoint? {
        var posValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
              let axValue = posValue else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return point
    }

    private func getWindowSize(_ window: AXUIElement) -> CGSize? {
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let axValue = sizeValue else { return nil }
        var size = CGSize.zero
        AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        return size
    }

    /// CGWindowID를 AXUIElement에서 추출
    private func getWindowID(_ window: AXUIElement) -> CGWindowID? {
        var windowID: CGWindowID = 0
        let result = _AXUIElementGetWindow(window, &windowID)
        guard result == .success else { return nil }
        return windowID
    }
}

// MARK: - Private C Function Bridge

/// AXUIElement에서 CGWindowID를 얻는 Private API 브릿지
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(
    _ element: AXUIElement,
    _ identifier: UnsafeMutablePointer<CGWindowID>
) -> AXError
