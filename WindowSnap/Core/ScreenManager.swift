import AppKit
import ApplicationServices
import Observation

// MARK: - ScreenManager

/// 연결된 모니터 목록 관리 및 화면 변경 이벤트 처리
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

    /// 마우스 커서 위치가 속하는 모니터를 반환
    func screenContaining(mouseLocation: CGPoint) -> NSScreen? {
        screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }

    /// 포커스 창이 주로 올라가 있는 모니터 (교차 면적 최대). 멀티 모니터에서 스냅 대상 화면 결정에 사용
    func screenForSnap(with window: AXUIElement) -> NSScreen? {
        guard let frame = WindowManager.shared.getWindowFrame(window) else { return nil }
        return screenContaining(frame: frame)
    }

    /// 지정된 CGRect 영역을 가장 많이 포함하는 모니터를 반환
    func screenContaining(frame: CGRect) -> NSScreen? {
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

    /// 인접 모니터(지정 방향으로 바로 옆 모니터)를 반환
    func adjacentScreen(to screen: NSScreen, direction: SnapTriggerZone) -> NSScreen? {
        switch direction {
        case .leftEdge:
            return screens.filter { $0.frame.maxX <= screen.frame.minX + 1 }
                .max(by: { $0.frame.minX < $1.frame.minX })
        case .rightEdge:
            return screens.filter { $0.frame.minX >= screen.frame.maxX - 1 }
                .min(by: { $0.frame.minX < $1.frame.minX })
        default:
            return nil
        }
    }

    /// 세로형 모니터인지 판단
    func isPortrait(_ screen: NSScreen) -> Bool {
        screen.frame.height > screen.frame.width
    }

    /// 메인 화면(가장 큰 해상도 기준) 반환
    var mainScreen: NSScreen {
        screens.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
            ?? (NSScreen.main ?? NSScreen.screens[0])
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
