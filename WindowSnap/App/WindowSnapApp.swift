import SwiftUI

// MARK: - WindowSnapApp

/// 앱 진입점: 메뉴바 전용 앱 (Dock 아이콘 없음)
@main
struct WindowSnapApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 설정 창 (⌘, 단축키로 열기)
        Settings {
            PreferencesView()
        }
    }
}
