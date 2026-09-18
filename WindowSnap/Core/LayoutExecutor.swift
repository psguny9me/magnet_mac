import AppKit

// MARK: - LayoutExecutor

/// 레이아웃 프리셋을 포커스 창에 적용하는 단일 진입점 (메인 스레드 전용)
///
/// 키보드 단축키, 메뉴바, 드래그 트리거가 모두 이 타입을 거친다.
/// 복원·중앙·모니터 이동 같은 특수 레이아웃은 이름이 아니라 `LayoutPreset.builtInKind`로 판별한다.
/// 호출자는 메인 스레드(DispatchQueue.main 또는 @MainActor)에서 부른다. 의존 타입들이 nonisolated라 격리 표시는 두지 않는다
enum LayoutExecutor {

    /// 포커스 창에 레이아웃을 적용한다. 대상 화면은 창이 속한 화면 → 마우스 화면 → 메인 화면 순으로 고른다
    static func apply(_ layout: LayoutPreset) {
        guard let window = WindowManager.shared.getFocusedWindow(),
              let screen = targetScreen(for: window) else { return }
        apply(layout, to: window, on: screen)
    }

    /// 지정한 창과 화면에 레이아웃을 적용한다 (드래그 트리거처럼 대상이 이미 정해진 경우)
    static func apply(_ layout: LayoutPreset, to window: AXUIElement, on screen: NSScreen) {
        let manager = WindowManager.shared
        let settings = AppSettings.shared

        switch layout.builtInKind {
        case .restore:
            manager.restoreOriginalFrame(for: window)
        case .center:
            guard let currentFrame = manager.getWindowFrame(window) else { return }
            manager.storeOriginalFrameIfNeeded(for: window)
            let centeredFrame = SnapCalculator.shared.calculateCenterFrame(
                windowSize: currentFrame.size,
                on: screen,
                settings: settings
            )
            manager.setWindowFrame(window, frame: centeredFrame)
        case .moveToMonitor1:
            manager.moveFocusedWindowToMonitor(oneBasedIndex: 1)
        case .moveToMonitor2:
            manager.moveFocusedWindowToMonitor(oneBasedIndex: 2)
        case .moveToMonitor3:
            manager.moveFocusedWindowToMonitor(oneBasedIndex: 3)
        default:
            // 일반 내장 레이아웃과 커스텀 레이아웃. 크기 0인 프레임은 창을 없애므로 적용하지 않는다
            guard layout.frame.width > 0, layout.frame.height > 0 else { return }
            manager.snapWindow(window, to: layout, on: screen)
        }
    }

    /// Step 2: 창이 속한 화면 → 마우스가 있는 화면 → `NSScreen.main`
    static func targetScreen(for window: AXUIElement) -> NSScreen? {
        ScreenManager.shared.screenForSnap(with: window)
            ?? ScreenManager.shared.screenContaining(mouseLocation: NSEvent.mouseLocation)
            ?? NSScreen.main
    }
}
