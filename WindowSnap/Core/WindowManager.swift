import AppKit
import ApplicationServices

// MARK: - WindowManager

/// AXUIElement API를 이용한 창 이동/리사이즈 핵심 제어 클래스
final class WindowManager {

    // MARK: - Singleton

    nonisolated(unsafe) static let shared = WindowManager()

    // MARK: - Private State

    /// 복원용 원본 프레임 항목. CGWindowID는 창이 닫히면 재사용될 수 있어 pid를 함께 기록한다
    private struct OriginalFrameEntry {
        let pid: pid_t
        let frame: CGRect
    }

    /// 스냅 전 원본 프레임 저장소 (복원 기능용)
    private var originalFrames: [CGWindowID: OriginalFrameEntry] = [:]

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
        guard result == .success, let window = focusedWindow,
              CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
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
    ///
    /// 순서가 중요하다: 위치를 먼저 옮기면 목표보다 큰 창이 화면 경계를 넘어가고,
    /// 그 상태에서 경계에 맞닿는 크기 요청은 AppKit이 (성공을 반환하면서) 무시한다.
    /// 그래서 1) 목표보다 조금 작게 줄여 화면 안에 들게 한 뒤 2) 이동하고 3) 정확한 크기를 적용한다.
    func setWindowFrame(_ window: AXUIElement, frame: CGRect) {
        var position = frame.origin
        var size = frame.size
        // 이미 경계에 걸쳐 있는 창은 경계에 정확히 맞는 첫 크기 요청도 무시되므로 여유를 둔다
        var shrunkSize = CGSize(
            width: max(frame.width - Self.preShrinkInset, 1),
            height: max(frame.height - Self.preShrinkInset, 1)
        )
        guard let posValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size),
              let shrunkValue = AXValueCreate(.cgSize, &shrunkSize) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, shrunkValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }

    /// 첫 번째 크기 설정에서 목표보다 줄여 두는 여유(pt). 실측상 경계에서 약 20~40pt 이내 요청은 무시된다.
    private static let preShrinkInset: CGFloat = 50

    /// 창의 현재 프레임(CGRect)을 읽어서 반환
    func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        guard let position = getWindowPosition(window),
              let size = getWindowSize(window) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// 스냅 전 원본 프레임을 저장 (아직 저장되지 않은 경우에만)
    func storeOriginalFrameIfNeeded(for window: AXUIElement) {
        pruneStaleOriginalFrames()
        guard let windowID = getWindowID(window),
              let pid = getPID(window) else { return }
        // 같은 CGWindowID라도 다른 프로세스면 재사용된 id이므로 덮어쓴다
        if let existing = originalFrames[windowID], existing.pid == pid { return }
        guard let frame = getWindowFrame(window) else { return }
        originalFrames[windowID] = OriginalFrameEntry(pid: pid, frame: frame)
    }

    /// 저장된 원본 프레임으로 창을 복원
    func restoreOriginalFrame(for window: AXUIElement) {
        guard let windowID = getWindowID(window),
              let pid = getPID(window),
              let entry = originalFrames[windowID], entry.pid == pid else { return }
        setWindowFrame(window, frame: entry.frame)
        originalFrames.removeValue(forKey: windowID)
    }

    /// 종료된 프로세스의 항목을 제거해 저장소가 무한히 커지지 않게 한다
    private func pruneStaleOriginalFrames() {
        originalFrames = originalFrames.filter { _, entry in
            NSRunningApplication(processIdentifier: entry.pid) != nil
        }
    }

    // MARK: - Private Helpers

    private func getWindowPosition(_ window: AXUIElement) -> CGPoint? {
        var posValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
              let axValue = posValue, CFGetTypeID(axValue) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func getWindowSize(_ window: AXUIElement) -> CGSize? {
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let axValue = sizeValue, CFGetTypeID(axValue) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axValue as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    private func getPID(_ window: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else { return nil }
        return pid
    }

    /// CGWindowID를 AXUIElement에서 추출. 비공개 API가 없는 OS에서는 nil (복원 기능만 비활성화)
    private func getWindowID(_ window: AXUIElement) -> CGWindowID? {
        guard let getWindow = Self.axGetWindowFunction else { return nil }
        var windowID: CGWindowID = 0
        guard getWindow(window, &windowID) == .success else { return nil }
        return windowID
    }

    // MARK: - Private API (dlsym)

    private typealias AXGetWindowFunction = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    /// `_AXUIElementGetWindow`는 비공개 API라 링크 시점에 묶으면 심볼이 사라졌을 때 앱이 뜨지 않는다.
    /// 실행 시점에 찾아서 없으면 nil로 두어 창 식별 기능만 꺼지게 한다
    private static let axGetWindowFunction: AXGetWindowFunction? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(symbol, to: AXGetWindowFunction.self)
    }()
}
