import AppKit
import ApplicationServices
import SwiftUI

// MARK: - AppDelegate

/// 앱 생명주기 및 핵심 서비스 초기화 담당 (메인 스레드 전용)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// 온보딩 창 (완료 시 직접 닫기 위해 보관)
    private var onboardingWindow: NSWindow?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 메뉴바 아이콘 설정
        setupMenuBarIfNeeded()

        // 온보딩 미완료 시 온보딩 표시, 완료 시 바로 서비스 시작
        if AppSettings.shared.hasCompletedOnboarding {
            startCoreServices()
        } else {
            showOnboarding()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // 시스템 설정에서 접근성을 켠 뒤 복귀했을 때 이벤트 탭이 아직 없을 수 있음
        synchronizeAccessibilityDependentServices()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 앱 종료 전 이벤트 탭 정리
        KeyboardShortcutManager.shared.stopListening()
        DragMonitor.shared.stopMonitoring()
    }

    // MARK: - Setup Helpers

    private func setupMenuBarIfNeeded() {
        let settings = AppSettings.shared
        if settings.showMenuBarIcon {
            MenuBarController.shared.setupMenuBar()
        }
        // Accessibility 권한 없으면 경고 배지 표시
        if !AXIsProcessTrusted() {
            MenuBarController.shared.showAccessibilityWarning()
        }
    }

    /// 단축키·액션 매핑을 등록하고, 접근성 권한이 있으면 이벤트 탭을 시작한다.
    /// 최초 실행, 온보딩 완료, 접근성 허용 후 복귀 세 경로가 모두 이 함수를 쓴다 (경로별 구현 드리프트 방지)
    private func startCoreServices() {
        let settings = AppSettings.shared

        // 단축키 등록
        let presets = settings.makeBuiltInPresets() + settings.customLayouts
        KeyboardShortcutManager.shared.registerShortcuts(from: presets)
        KeyboardShortcutManager.shared.registerActionShortcuts(settings.makeActionShortcutMap())

        // Accessibility 권한 있을 때만 이벤트 탭 시작 (이미 켜져 있으면 내부에서 무시)
        if AXIsProcessTrusted() {
            KeyboardShortcutManager.shared.startListening()
            if settings.dragTriggerEnabled {
                DragMonitor.shared.startMonitoring()
            }
        }
    }

    /// 접근성 허용 후 복귀 시 단축키·드래그 모니터를 다시 붙임 (최초 거부 후 허용 대응)
    private func synchronizeAccessibilityDependentServices() {
        guard AXIsProcessTrusted() else { return }
        startCoreServices()
    }

    private func showOnboarding() {
        let onboardingView = OnboardingView { [weak self] in
            self?.finishOnboarding()
        }
        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "WindowSnap 시작하기"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 온보딩 완료: 창을 직접 닫고 (수동 생성 NSWindow는 SwiftUI dismiss로 닫히지 않음) 핵심 서비스 시작
    private func finishOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
        startCoreServices()
    }

    // MARK: - Settings Window

    @objc func showPreferencesWindow(_ sender: Any?) {
        let preferencesView = PreferencesView()
        let hostingController = NSHostingController(rootView: preferencesView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "환경설정"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
