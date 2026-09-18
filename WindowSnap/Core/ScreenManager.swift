import AppKit
import ApplicationServices
import Observation

// MARK: - ScreenManager

/// 연결된 모니터 목록 관리 및 화면 변경 이벤트 처리
///
/// Multi-monitor snap — Step 1 & 2 here; Step 3 (BL global ↔ AX) lives in `SnapCalculator`.
/// Manual check: single display; side-by-side; stacked; menu bar on external if applicable.
@Observable
final class ScreenManager: @unchecked Sendable {

    // MARK: - Singleton

    nonisolated(unsafe) static let shared = ScreenManager()

    // MARK: - Observed State

    /// 현재 연결된 모니터 목록 (변경 시 UI 자동 업데이트)
    private(set) var screens: [NSScreen] = NSScreen.screens

    // MARK: - Init

    private init() {
        observeScreenChanges()
    }

    // MARK: - Public API

    /// 마우스 커서 위치가 속하는 모니터를 반환 (`NSScreen.screens` 직접 사용 — 캐시와 불일치 방지)
    func screenContaining(mouseLocation: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }

    /// 모니터 1…N (`NSScreen.screens` 순서). 요청 인덱스가 없으면 마지막 모니터로 클램프
    func effectiveScreen(forOneBasedIndex index: Int) -> NSScreen? {
        let list = NSScreen.screens
        guard !list.isEmpty else { return NSScreen.main }
        let clampedIndex = min(max(index, 1), list.count)
        return list[clampedIndex - 1]
    }

    /// Step 2 (keyboard / menu): focused window’s screen via AX frame → bottom-left global → max intersection with `screen.frame`
    func screenForSnap(with window: AXUIElement) -> NSScreen? {
        guard let axFrame = WindowManager.shared.getWindowFrame(window) else { return nil }
        let bottomLeftFrame = SnapCalculator.shared.convertAXFrameToBottomLeftGlobal(axFrame)
        return screenContainingBottomLeftGlobalFrame(bottomLeftFrame)
    }

    /// 좌하단 원점 글로벌 좌표의 영역과 교차 면적이 가장 큰 모니터 반환 (NSScreen.frame과 동일 계열)
    private func screenContainingBottomLeftGlobalFrame(_ frame: CGRect) -> NSScreen? {
        var bestScreen: NSScreen?
        var largestIntersection: CGFloat = 0
        for screen in screens {
            let intersection = screen.frame.intersection(frame)
            let intersectionArea = intersection.width * intersection.height
            if intersectionArea > largestIntersection {
                largestIntersection = intersectionArea
                bestScreen = screen
            }
        }
        return bestScreen ?? NSScreen.main
    }

    // MARK: - Screen Change Observer

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenParametersChange()
        }
    }

    private func handleScreenParametersChange() {
        screens = NSScreen.screens
        // 화면 구성 변경 시 관심 있는 컴포넌트에 알림 전달
        NotificationCenter.default.post(
            name: .screenConfigurationDidChange,
            object: nil
        )
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// 화면(모니터) 구성이 변경되었을 때 발행되는 알림
    static let screenConfigurationDidChange = Notification.Name("screenConfigurationDidChange")
}
