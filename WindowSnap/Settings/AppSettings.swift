import Foundation
import Observation
import ServiceManagement

// MARK: - SettingsKey

/// UserDefaults 저장 키 상수
enum SettingsKey: String {
    case launchAtLogin          = "launchAtLogin"
    case showMenuBarIcon        = "showMenuBarIcon"
    case dragTriggerEnabled     = "dragTriggerEnabled"
    case dragTriggerThreshold   = "dragTriggerThreshold"
    case snapPreviewEnabled     = "snapPreviewEnabled"
    case greenButtonMenuEnabled = "greenButtonMenuEnabled"
    case ignoreMenuBar          = "ignoreMenuBar"
    case ignoreDock             = "ignoreDock"
    case halfRatio              = "halfRatio"
    case thirdRatio             = "thirdRatio"
    case customLayouts          = "customLayouts"
    case shortcutBindings       = "shortcutBindings"
    case hasCompletedOnboarding = "hasCompletedOnboarding"
    case clipboardSaveDirectory = "clipboardSaveDirectory"
}

// MARK: - AppSettings

/// 앱 전역 설정 관리 클래스 (@Observable, Swift 6)
@Observable
final class AppSettings {

    // MARK: - Singleton

    nonisolated(unsafe) static let shared = AppSettings()

    // MARK: - General Settings

    /// 로그인 시 자동 실행
    var launchAtLogin: Bool = true {
        didSet { saveBool(launchAtLogin, for: .launchAtLogin); applyLaunchAtLogin() }
    }

    /// 메뉴바 아이콘 표시 여부
    var showMenuBarIcon: Bool = true {
        didSet { saveBool(showMenuBarIcon, for: .showMenuBarIcon) }
    }

    /// 드래그 트리거 활성화 여부
    var dragTriggerEnabled: Bool = true {
        didSet { saveBool(dragTriggerEnabled, for: .dragTriggerEnabled) }
    }

    /// 드래그 트리거 감지 임계값 (px, 범위: 2~20)
    /// @Observable didSet 내 자기 재할당은 getKeyPath 크래시를 유발하므로 단순 저장만 수행
    var dragTriggerThreshold: Int = 4 {
        didSet { saveInt(dragTriggerThreshold, for: .dragTriggerThreshold) }
    }

    /// 스냅 미리보기 오버레이 표시 여부
    var snapPreviewEnabled: Bool = true {
        didSet { saveBool(snapPreviewEnabled, for: .snapPreviewEnabled) }
    }

    /// Green Button 팝오버 메뉴 활성화 여부
    var greenButtonMenuEnabled: Bool = true {
        didSet { saveBool(greenButtonMenuEnabled, for: .greenButtonMenuEnabled) }
    }

    /// 전체화면 시 메뉴바 공간 제외 여부
    var ignoreMenuBar: Bool = true {
        didSet { saveBool(ignoreMenuBar, for: .ignoreMenuBar) }
    }

    /// 레이아웃 계산 시 Dock 공간 제외 여부
    var ignoreDock: Bool = true {
        didSet { saveBool(ignoreDock, for: .ignoreDock) }
    }

    // MARK: - Layout Ratio Settings

    /// 절반 분할 비율 (0.3 ~ 0.7) - 로드 시 clamping 적용, setter에서 단순 저장
    var halfRatio: Double = 0.5 {
        didSet { saveDouble(halfRatio, for: .halfRatio) }
    }

    /// 1/3 분할 비율 - 로드 시 clamping 적용, setter에서 단순 저장
    var thirdRatio: Double = 1.0 / 3.0 {
        didSet { saveDouble(thirdRatio, for: .thirdRatio) }
    }

    // MARK: - Custom Layouts

    /// 사용자 정의 커스텀 레이아웃 목록
    var customLayouts: [LayoutPreset] = [] {
        didSet { saveCustomLayouts() }
    }

    // MARK: - Shortcut Bindings

    /// 레이아웃 ID -> 단축키 매핑 (기본 프리셋 포함)
    var shortcutBindings: [String: ShortcutBinding] = [:] {
        didSet { saveShortcutBindings() }
    }

    // MARK: - Clipboard Image Save

    /// 클립보드 이미지 저장 폴더 경로 (기본: 데스크탑)
    var clipboardSaveDirectoryPath: String = AppSettings.defaultClipboardSaveDirectoryPath {
        didSet { saveString(clipboardSaveDirectoryPath, for: .clipboardSaveDirectory) }
    }

    /// 기본 저장 폴더 경로 (데스크탑)
    static var defaultClipboardSaveDirectoryPath: String {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path
            ?? (NSHomeDirectory() as NSString).appendingPathComponent("Desktop")
    }

    /// 클립보드 이미지 저장 단축키 (사용자 커스터마이징 반영)
    func clipboardSaveShortcut() -> ShortcutBinding {
        shortcutBindings[AppShortcutAction.saveClipboardImage.rawValue]
            ?? AppShortcutAction.saveClipboardImage.defaultShortcut
    }

    /// 액션 단축키 매핑 테이블 생성
    func makeActionShortcutMap() -> [ShortcutBinding: AppShortcutAction] {
        [clipboardSaveShortcut(): .saveClipboardImage]
    }

    // MARK: - Onboarding

    /// 온보딩 완료 여부
    var hasCompletedOnboarding: Bool = false {
        didSet { saveBool(hasCompletedOnboarding, for: .hasCompletedOnboarding) }
    }

    // MARK: - Init

    private init() {
        loadAllSettings()
    }

    // MARK: - Built-in Presets

    /// 현재 비율 설정으로 기본 레이아웃 프리셋 목록 생성
    func makeBuiltInPresets() -> [LayoutPreset] {
        BuiltInLayout.allCases.map { layout in
            var preset = layout.makeLayoutPreset(halfRatio: halfRatio, thirdRatio: thirdRatio)
            // 사용자가 커스터마이징한 단축키가 있으면 반영
            if let customShortcut = shortcutBindings[layout.rawValue] {
                preset.shortcut = customShortcut
            }
            return preset
        }
    }

    // MARK: - Load

    private func loadAllSettings() {
        let defaults = UserDefaults.standard
        launchAtLogin          = defaults.object(forKey: SettingsKey.launchAtLogin.rawValue) as? Bool ?? true
        showMenuBarIcon        = defaults.object(forKey: SettingsKey.showMenuBarIcon.rawValue) as? Bool ?? true
        dragTriggerEnabled     = defaults.object(forKey: SettingsKey.dragTriggerEnabled.rawValue) as? Bool ?? true
        let rawThreshold = defaults.object(forKey: SettingsKey.dragTriggerThreshold.rawValue) as? Int ?? 4
        dragTriggerThreshold   = max(2, min(20, rawThreshold))
        snapPreviewEnabled     = defaults.object(forKey: SettingsKey.snapPreviewEnabled.rawValue) as? Bool ?? true
        greenButtonMenuEnabled = defaults.object(forKey: SettingsKey.greenButtonMenuEnabled.rawValue) as? Bool ?? true
        ignoreMenuBar          = defaults.object(forKey: SettingsKey.ignoreMenuBar.rawValue) as? Bool ?? true
        ignoreDock             = defaults.object(forKey: SettingsKey.ignoreDock.rawValue) as? Bool ?? true
        let rawHalfRatio = defaults.object(forKey: SettingsKey.halfRatio.rawValue) as? Double ?? 0.5
        halfRatio              = max(0.3, min(0.7, rawHalfRatio))
        let rawThirdRatio = defaults.object(forKey: SettingsKey.thirdRatio.rawValue) as? Double ?? (1.0 / 3.0)
        thirdRatio             = max(0.2, min(0.45, rawThirdRatio))
        hasCompletedOnboarding = defaults.object(forKey: SettingsKey.hasCompletedOnboarding.rawValue) as? Bool ?? false
        clipboardSaveDirectoryPath = defaults.string(forKey: SettingsKey.clipboardSaveDirectory.rawValue)
            ?? AppSettings.defaultClipboardSaveDirectoryPath
        loadCustomLayouts()
        loadShortcutBindings()
    }

    private func loadCustomLayouts() {
        guard let data = UserDefaults.standard.data(forKey: SettingsKey.customLayouts.rawValue),
              let layouts = try? JSONDecoder().decode([LayoutPreset].self, from: data) else {
            customLayouts = []
            return
        }
        customLayouts = layouts
    }

    private func loadShortcutBindings() {
        guard let data = UserDefaults.standard.data(forKey: SettingsKey.shortcutBindings.rawValue),
              let bindings = try? JSONDecoder().decode([String: ShortcutBinding].self, from: data) else {
            shortcutBindings = [:]
            return
        }
        shortcutBindings = bindings
    }

    // MARK: - Save Helpers

    private func saveBool(_ value: Bool, for key: SettingsKey) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private func saveInt(_ value: Int, for key: SettingsKey) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private func saveDouble(_ value: Double, for key: SettingsKey) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private func saveString(_ value: String, for key: SettingsKey) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private func saveCustomLayouts() {
        guard let data = try? JSONEncoder().encode(customLayouts) else { return }
        UserDefaults.standard.set(data, forKey: SettingsKey.customLayouts.rawValue)
    }

    private func saveShortcutBindings() {
        guard let data = try? JSONEncoder().encode(shortcutBindings) else { return }
        UserDefaults.standard.set(data, forKey: SettingsKey.shortcutBindings.rawValue)
    }

    // MARK: - Launch At Login

    private func applyLaunchAtLogin() {
        // 단위 테스트(xctest)나 명령줄 도구가 이 파일을 링크해도 로그인 항목에 등록되지 않도록 번들 앱에서만 수행
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 자동 실행 등록 실패는 무음 처리
        }
    }
}
