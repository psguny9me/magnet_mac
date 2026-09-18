import AppKit

// MARK: - MenuBarController

/// 메뉴바 아이콘 및 드롭다운 메뉴 관리 (메인 스레드 전용)
@MainActor
final class MenuBarController {

    // MARK: - Singleton

    @MainActor static let shared = MenuBarController()

    // MARK: - Private Properties

    private var statusItem: NSStatusItem?

    private init() {}

    // MARK: - Public API

    /// 메뉴바 아이콘 생성 및 표시
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusItemButton()
        rebuildMenu()
    }

    /// 메뉴바 아이콘 제거
    func removeMenuBar() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    /// Accessibility 권한 없음 경고 배지 표시
    func showAccessibilityWarning() {
        statusItem?.button?.image = NSImage(
            systemSymbolName: "exclamationmark.triangle.fill",
            accessibilityDescription: "Accessibility 권한 필요"
        )
    }

    /// 정상 상태 아이콘 복구
    func showNormalIcon() {
        configureStatusItemButton()
    }

    /// 설정 변경 시 메뉴 재구성
    func rebuildMenu() {
        let menu = buildMenu()
        statusItem?.menu = menu
    }

    // MARK: - Private Helpers

    private func configureStatusItemButton() {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(
            systemSymbolName: "rectangle.split.2x1",
            accessibilityDescription: "WindowSnap"
        )
        button.image?.isTemplate = true
    }

    // MARK: - Menu Builder

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // 현재 창 배치 서브메뉴
        let currentWindowItem = NSMenuItem(title: "현재 창 배치", action: nil, keyEquivalent: "")
        currentWindowItem.submenu = buildWindowLayoutMenu()
        menu.addItem(currentWindowItem)

        // 커스텀 레이아웃 서브메뉴
        let customItem = NSMenuItem(title: "커스텀 레이아웃", action: nil, keyEquivalent: "")
        customItem.submenu = buildCustomLayoutMenu()
        menu.addItem(customItem)

        menu.addItem(.separator())

        // 클립보드 이미지 저장
        let saveClipboardItem = NSMenuItem(
            title: "클립보드 이미지 저장",
            action: #selector(saveClipboardImage),
            keyEquivalent: ""
        )
        saveClipboardItem.target = self
        saveClipboardItem.toolTip = AppSettings.shared.clipboardSaveShortcut().displayString
        menu.addItem(saveClipboardItem)

        // 저장 폴더 열기
        let openSaveFolderItem = NSMenuItem(
            title: "저장 폴더 열기",
            action: #selector(openClipboardSaveFolder),
            keyEquivalent: ""
        )
        openSaveFolderItem.target = self
        menu.addItem(openSaveFolderItem)

        menu.addItem(.separator())

        // 환경설정
        let preferencesItem = NSMenuItem(
            title: "환경설정...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        // 이 Mac 정보
        let aboutItem = NSMenuItem(
            title: "WindowSnap 정보...",
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // 종료
        let quitItem = NSMenuItem(
            title: "종료",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    private func buildWindowLayoutMenu() -> NSMenu {
        let menu = NSMenu()

        // 절반 배치 그룹
        let halfMenu = buildSubMenu(title: "절반 배치", layouts: [
            .halfLeft, .halfRight, .halfTop, .halfBottom
        ])
        let halfItem = NSMenuItem(title: "절반 배치", action: nil, keyEquivalent: "")
        halfItem.submenu = halfMenu
        menu.addItem(halfItem)

        // 1/4 배치 그룹
        let quarterMenu = buildSubMenu(title: "1/4 배치", layouts: [
            .quarterTopLeft, .quarterTopRight, .quarterBottomLeft, .quarterBottomRight
        ])
        let quarterItem = NSMenuItem(title: "1/4 배치", action: nil, keyEquivalent: "")
        quarterItem.submenu = quarterMenu
        menu.addItem(quarterItem)

        // 1/3 배치 그룹
        let thirdMenu = buildSubMenu(title: "1/3 배치", layouts: [
            .thirdLeft, .thirdCenter, .thirdRight
        ])
        let thirdItem = NSMenuItem(title: "1/3 배치", action: nil, keyEquivalent: "")
        thirdItem.submenu = thirdMenu
        menu.addItem(thirdItem)

        // 2/3 배치 그룹
        let twoThirdMenu = buildSubMenu(title: "2/3 배치", layouts: [
            .twoThirdLeft, .twoThirdRight
        ])
        let twoThirdItem = NSMenuItem(title: "2/3 배치", action: nil, keyEquivalent: "")
        twoThirdItem.submenu = twoThirdMenu
        menu.addItem(twoThirdItem)

        menu.addItem(.separator())

        let monitorMenu = NSMenu(title: "모니터로 이동")
        for monitorLayout in [BuiltInLayout.moveToMonitor1, .moveToMonitor2, .moveToMonitor3] {
            addLayoutMenuItem(to: monitorMenu, layout: monitorLayout)
        }
        let monitorItem = NSMenuItem(title: "모니터로 이동", action: nil, keyEquivalent: "")
        monitorItem.submenu = monitorMenu
        menu.addItem(monitorItem)

        menu.addItem(.separator())

        // 전체화면, 중앙, 복원
        addLayoutMenuItem(to: menu, layout: .fullscreen)
        addLayoutMenuItem(to: menu, layout: .center)
        addLayoutMenuItem(to: menu, layout: .restore)

        return menu
    }

    private func buildSubMenu(title: String, layouts: [BuiltInLayout]) -> NSMenu {
        let menu = NSMenu(title: title)
        for layout in layouts {
            addLayoutMenuItem(to: menu, layout: layout)
        }
        return menu
    }

    private func addLayoutMenuItem(to menu: NSMenu, layout: BuiltInLayout) {
        let settings = AppSettings.shared
        let preset = layout.makeLayoutPreset(
            halfRatio: settings.halfRatio,
            thirdRatio: settings.thirdRatio
        )

        let item = NSMenuItem(
            title: layout.localizedName,
            action: #selector(applyBuiltInLayout(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = layout.rawValue

        // 단축키 표시 (첫 글자만 표시 한계 있으므로 툴팁으로 보완)
        if let shortcut = preset.shortcut {
            item.toolTip = shortcut.displayString
        }

        menu.addItem(item)
    }

    private func buildCustomLayoutMenu() -> NSMenu {
        let menu = NSMenu()
        let customLayouts = AppSettings.shared.customLayouts

        if customLayouts.isEmpty {
            let emptyItem = NSMenuItem(title: "커스텀 레이아웃 없음", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for layout in customLayouts {
                let item = NSMenuItem(
                    title: layout.name,
                    action: #selector(applyCustomLayout(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = layout.id.uuidString
                menu.addItem(item)
            }
        }
        return menu
    }

    // MARK: - Actions

    @objc private func applyBuiltInLayout(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let builtIn = BuiltInLayout(rawValue: rawValue) else { return }
        let settings = AppSettings.shared
        let preset = builtIn.makeLayoutPreset(
            halfRatio: settings.halfRatio,
            thirdRatio: settings.thirdRatio
        )
        LayoutExecutor.apply(preset)
    }

    @objc private func applyCustomLayout(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let uuid = UUID(uuidString: idString),
              let layout = AppSettings.shared.customLayouts.first(where: { $0.id == uuid }) else { return }
        LayoutExecutor.apply(layout)
    }

    @objc private func saveClipboardImage() {
        ClipboardImageSaver.shared.saveClipboardImage()
    }

    @objc private func openClipboardSaveFolder() {
        NSWorkspace.shared.open(ClipboardImageSaver.shared.saveDirectoryURL())
    }

    @objc private func openPreferences() {
        // 메뉴바 전용 앱(LSUIElement)에서는 SwiftUI Settings 씬을 여는 showSettingsWindow: 액션이 동작하지 않는 경우가 있어
        // AppDelegate가 관리하는 단일 환경설정 창을 연다.
        // 주의: @NSApplicationDelegateAdaptor 환경에서는 NSApp.delegate가 SwiftUI의 델리게이트라 캐스트할 수 없으므로
        // 응답자 체인으로 액션을 보낸다 (SwiftUI 델리게이트가 우리 AppDelegate로 전달한다)
        NSApp.sendAction(#selector(AppDelegate.showPreferencesWindow(_:)), to: nil, from: nil)
    }

    @objc private func openAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
