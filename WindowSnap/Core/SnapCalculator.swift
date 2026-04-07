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
/// - Step 3: This type converts that screen’s `frame` / `visibleFrame` (bottom-left global) to AX space using `NSScreen.main` as the kAXPosition Y reference (menu bar screen), then `LayoutPreset.toAbsoluteFrame(in:)`.
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

    /// 화면 프레임 해석: 메뉴바/Dock 제외 여부에 따라 visibleFrame 또는 frame 사용
    func resolveScreenFrame(screen: NSScreen, settings: AppSettings) -> CGRect {
        // macOS에서 AXUIElement는 좌상단 원점 좌표계를 사용하므로 변환 필요
        let frame = (settings.ignoreMenuBar || settings.ignoreDock)
            ? screen.visibleFrame
            : screen.frame
        return convertToTopLeftOrigin(frame: frame, screen: screen)
    }

    /// 세로형 모니터 여부 판단
    func isPortraitMonitor(_ screen: NSScreen) -> Bool {
        screen.frame.height > screen.frame.width
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

    /// 마우스 위치에 해당하는 화면 내 트리거 영역의 미리보기 CGRect 반환
    func calculatePreviewFrame(
        for zone: SnapTriggerZone,
        on screen: NSScreen,
        settings: AppSettings
    ) -> CGRect {
        let layout = zone.builtInLayout.makeLayoutPreset(
            halfRatio: settings.halfRatio,
            thirdRatio: settings.thirdRatio
        )
        return calculateAbsoluteFrame(for: layout, on: screen, settings: settings)
    }

    // MARK: - Center Frame Calculation

    /// 현재 창 크기를 유지하면서 화면 중앙에 배치할 프레임 반환
    func calculateCenterFrame(windowSize: CGSize, on screen: NSScreen, settings: AppSettings) -> CGRect {
        let screenFrame = resolveScreenFrame(screen: screen, settings: settings)
        let centeredX = screenFrame.midX - windowSize.width / 2
        let centeredY = screenFrame.midY - windowSize.height / 2
        return CGRect(origin: CGPoint(x: centeredX, y: centeredY), size: windowSize)
    }

    // MARK: - Portrait Monitor Layout Rotation

    /// 세로형 모니터에서 레이아웃 프레임을 90도 회전 적용
    /// 가로 레이아웃(좌/우 절반, 1/3 등) -> 세로 레이아웃(상/하 절반, 1/3 등)으로 변환
    func rotateFrameForPortrait(_ frame: RelativeFrame) -> RelativeFrame {
        // x,y와 width,height를 교환하여 회전 효과
        return RelativeFrame(
            x: frame.y,
            y: frame.x,
            width: frame.height,
            height: frame.width
        )
    }

    /// 세로형 모니터에서 최적화된 레이아웃 프레임 반환
    func calculateAbsoluteFrameAdaptive(
        for layout: LayoutPreset,
        on screen: NSScreen,
        settings: AppSettings
    ) -> CGRect {
        // 세로형 모니터 감지: ScreenManager 없이 직접 판단
        let isPortrait = screen.frame.height > screen.frame.width
        var adaptedLayout = layout
        if isPortrait {
            // 세로형 모니터에서 가로 레이아웃을 세로 방향으로 자동 전환
            adaptedLayout = LayoutPreset(
                id: layout.id,
                name: layout.name,
                frame: rotateFrameForPortrait(layout.frame),
                shortcut: layout.shortcut,
                isBuiltIn: layout.isBuiltIn
            )
        }
        return calculateAbsoluteFrame(for: adaptedLayout, on: screen, settings: settings)
    }

    // MARK: - Coordinate System Conversion

    /// Bottom-edge Y of the menu bar screen in NSScreen global coords (Y up). Matches kAXPosition (0,0) = top-left of that screen.
    private func menuBarScreenMaxYBottomLeftGlobal() -> CGFloat? {
        NSScreen.main?.frame.maxY
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

    // MARK: - Multi-Monitor Scale Factor Handling

    /// 화면 간 좌표 변환 시 스케일 팩터 차이를 보정
    /// (예: Retina XDR -> HP FHD로 드래그 시 포인트 단위 유지)
    func normalizePoint(_ point: CGPoint, fromScreen: NSScreen, toScreen: NSScreen) -> CGPoint {
        // NSScreen 좌표계는 이미 포인트 단위이므로 별도 변환 불필요
        // 다만 스케일 팩터가 다른 화면 간 이동 시 논리 픽셀 기준으로 처리됨
        return point
    }
}
