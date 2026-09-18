import AppKit

// MARK: - SnapTriggerZone

/// 드래그 트리거 영역 종류
enum SnapTriggerZone {
    case leftEdge
    case rightEdge
    case topEdge
    case bottomEdge
    case topLeftCorner
    case topRightCorner
    case bottomLeftCorner
    case bottomRightCorner

    /// 트리거 영역에 대응하는 레이아웃 종류
    var builtInLayout: BuiltInLayout {
        switch self {
        case .leftEdge:         return .halfLeft
        case .rightEdge:        return .halfRight
        case .topEdge:          return .fullscreen
        case .bottomEdge:       return .halfBottom
        case .topLeftCorner:    return .quarterTopLeft
        case .topRightCorner:   return .quarterTopRight
        case .bottomLeftCorner: return .quarterBottomLeft
        case .bottomRightCorner:return .quarterBottomRight
        }
    }
}

// MARK: - SnapCalculator

/// 레이아웃 프리셋의 절대 좌표 계산 및 드래그 트리거 영역 판단
///
/// Multi-monitor snap pipeline (see also `ScreenManager`):
/// - Step 1: `ScreenManager.isMultiMonitor` — whether `screens.count > 1` (diagnostics / branching).
/// - Step 2: Target `NSScreen` — keyboard/menu use focused window (`screenForSnap`); drag uses cursor (`screenContaining(mouseLocation:)`).
/// - Step 3: This type converts that screen’s `frame` / `visibleFrame` (bottom-left global) to AX space using `NSScreen.screens[0]` (the primary/menu bar screen, origin (0,0)) as the kAXPosition Y reference, then `LayoutPreset.toAbsoluteFrame(in:)`.
final class SnapCalculator {

    // MARK: - Singleton

    nonisolated(unsafe) static let shared = SnapCalculator()
    private init() {}

    // MARK: - Frame Calculation

    /// 레이아웃 프리셋을 지정 화면의 절대 픽셀 좌표(CGRect)로 변환
    /// - Parameters:
    ///   - layout: 적용할 레이아웃 프리셋
    ///   - screen: 대상 NSScreen
    ///   - settings: 현재 앱 설정 (비율, 메뉴바/Dock 제외 여부)
    func calculateAbsoluteFrame(
        for layout: LayoutPreset,
        on screen: NSScreen,
        settings: AppSettings
    ) -> CGRect {
        let screenFrame = resolveScreenFrame(screen: screen, settings: settings)

        // center, restore는 특수 처리: 여기서는 visibleFrame 중앙 배치
        if layout.frame.width == 0 && layout.frame.height == 0 {
            return screenFrame // caller에서 특수 처리
        }

        return layout.frame.toAbsoluteFrame(in: screenFrame)
    }

    /// 화면 프레임 해석: 메뉴바 제외와 Dock 제외를 각각 독립적으로 적용한다
    /// (visibleFrame은 둘을 한꺼번에 뺀 값이라 frame과의 차이를 위쪽 = 메뉴바, 아래·좌·우 = Dock으로 나눈다)
    func resolveScreenFrame(screen: NSScreen, settings: AppSettings) -> CGRect {
        let frame = usableFrame(
            frame: screen.frame,
            visibleFrame: screen.visibleFrame,
            ignoreMenuBar: settings.ignoreMenuBar,
            ignoreDock: settings.ignoreDock
        )
        // macOS에서 AXUIElement는 좌상단 원점 좌표계를 사용하므로 변환 필요
        return convertToTopLeftOrigin(frame: frame, screen: screen)
    }

    /// 좌하단 원점 좌표계에서 메뉴바/Dock 영역을 선택적으로 제외한 프레임 (순수 계산, 테스트 가능)
    func usableFrame(frame: CGRect, visibleFrame: CGRect, ignoreMenuBar: Bool, ignoreDock: Bool) -> CGRect {
        var result = frame
        if ignoreMenuBar {
            let topInset = max(0, frame.maxY - visibleFrame.maxY)
            result.size.height -= topInset
        }
        if ignoreDock {
            let bottomInset = max(0, visibleFrame.minY - frame.minY)
            let leftInset = max(0, visibleFrame.minX - frame.minX)
            let rightInset = max(0, frame.maxX - visibleFrame.maxX)
            result.origin.y += bottomInset
            result.size.height -= bottomInset
            result.origin.x += leftInset
            result.size.width -= leftInset + rightInset
        }
        return result
    }

    // MARK: - Drag Trigger Detection

    /// 마우스 위치(전체 화면 좌표)가 어느 트리거 영역에 속하는지 판단
    /// - Parameters:
    ///   - mouseLocation: 전역 마우스 좌표 (macOS 좌하단 원점)
    ///   - screen: 기준 화면
    ///   - threshold: 가장자리 감지 임계값 (px)
    func detectTriggerZone(
        at mouseLocation: CGPoint,
        on screen: NSScreen,
        threshold: CGFloat
    ) -> SnapTriggerZone? {
        let screenFrame = screen.frame
        let maxX = screenFrame.maxX
        let maxY = screenFrame.maxY
        let minX = screenFrame.minX
        let minY = screenFrame.minY

        let isAtLeft   = mouseLocation.x <= minX + threshold
        let isAtRight  = mouseLocation.x >= maxX - threshold
        let isAtTop    = mouseLocation.y >= maxY - threshold
        let isAtBottom = mouseLocation.y <= minY + threshold

        // 모서리 우선 판단
        if isAtLeft  && isAtTop    { return .topLeftCorner }
        if isAtRight && isAtTop    { return .topRightCorner }
        if isAtLeft  && isAtBottom { return .bottomLeftCorner }
        if isAtRight && isAtBottom { return .bottomRightCorner }

        // 가장자리 판단
        if isAtLeft   { return .leftEdge }
        if isAtRight  { return .rightEdge }
        if isAtTop    { return .topEdge }
        if isAtBottom { return .bottomEdge }

        return nil
    }

    // MARK: - Center Frame Calculation

    /// 현재 창 크기를 유지하면서 화면 중앙에 배치할 프레임 반환
    func calculateCenterFrame(windowSize: CGSize, on screen: NSScreen, settings: AppSettings) -> CGRect {
        let screenFrame = resolveScreenFrame(screen: screen, settings: settings)
        let centeredX = screenFrame.midX - windowSize.width / 2
        let centeredY = screenFrame.midY - windowSize.height / 2
        return CGRect(origin: CGPoint(x: centeredX, y: centeredY), size: windowSize)
    }

    // MARK: - Coordinate System Conversion

    /// Top edge (maxY) of the primary screen in NSScreen global coords (Y up). kAXPosition (0,0) is the top-left of that screen.
    /// `NSScreen.screens[0]` is always the primary (menu bar) screen; `NSScreen.main` is the keyboard-focus screen and must not be used here.
    private func menuBarScreenMaxYBottomLeftGlobal() -> CGFloat? {
        NSScreen.screens.first?.frame.maxY
    }

    /// NSScreen.frame / visibleFrame(좌하단 원점 글로벌) -> AX kAXPosition/kAXSize용 (좌상단 원점, Y 아래)
    func convertToTopLeftOrigin(frame: CGRect, screen _: NSScreen) -> CGRect {
        guard let menuBarMaxY = menuBarScreenMaxYBottomLeftGlobal() else { return frame }
        let convertedY = menuBarMaxY - frame.maxY
        return CGRect(x: frame.origin.x, y: convertedY, width: frame.width, height: frame.height)
    }

    /// AX에서 읽은 창 프레임(좌상단 원점, Y 아래) -> NSScreen.frame과 동일한 좌하단 글로벌 좌표
    func convertAXFrameToBottomLeftGlobal(_ axFrame: CGRect) -> CGRect {
        guard let menuBarMaxY = menuBarScreenMaxYBottomLeftGlobal() else { return axFrame }
        let bottomLeftOriginY = menuBarMaxY - axFrame.maxY
        return CGRect(x: axFrame.origin.x, y: bottomLeftOriginY, width: axFrame.width, height: axFrame.height)
    }
}
