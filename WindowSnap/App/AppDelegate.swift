import AppKit
import ApplicationServices
import SwiftUI

// MARK: - AppDelegate

/// 앱 생명주기 및 핵심 서비스 초기화 담당 (메인 스레드 전용)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

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

    private func startCoreServices() {
        let settings = AppSettings.shared

        // 단축키 등록
        let presets = settings.makeBuiltInPresets() + settings.customLayouts
        KeyboardShortcutManager.shared.registerShortcuts(from: presets)

        // Accessibility 권한 있을 때만 이벤트 탭 시작
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
        let settings = AppSettings.shared
        let presets = settings.makeBuiltInPresets() + settings.customLayouts
        KeyboardShortcutManager.shared.registerShortcuts(from: presets)
        KeyboardShortcutManager.shared.startListening()
        if settings.dragTriggerEnabled {
            DragMonitor.shared.startMonitoring()
        }
    }

    private func showOnboarding() {
        let onboardingView = OnboardingView()
        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "WindowSnap 시작하기"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
