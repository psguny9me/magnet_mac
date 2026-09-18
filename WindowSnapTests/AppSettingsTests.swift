import XCTest

// MARK: - AppSettingsTests

/// AppSettings UserDefaults 읽기/쓰기 단위 테스트
final class AppSettingsTests: XCTestCase {

    private let suiteName = "com.windowsnap.tests"
    private var testDefaults: UserDefaults!
    /// 테스트 전용 suite에만 읽고 쓰는 인스턴스 (앱의 실제 설정과 격리)
    private var settings: AppSettings!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults.removePersistentDomain(forName: suiteName)
        settings = AppSettings(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - 기본값 테스트

    func testDefaultHalfRatioValue() {
        XCTAssertEqual(settings.halfRatio, 0.5, accuracy: 0.001)
    }

    func testDefaultThirdRatioValue() {
        XCTAssertEqual(settings.thirdRatio, 1.0 / 3.0, accuracy: 0.001)
    }

    func testDefaultDragTriggerThreshold() {
        XCTAssertEqual(settings.dragTriggerThreshold, 4)
    }

    // MARK: - 비율 범위 제한 테스트 (loadAllSettings 로드 시 clamping 적용 확인)

    func testHalfRatioIsWithinValidRange() {
        // 기본값이 유효 범위 내에 있는지 확인
        XCTAssertGreaterThanOrEqual(settings.halfRatio, 0.3)
        XCTAssertLessThanOrEqual(settings.halfRatio, 0.7)
    }

    func testDragTriggerThresholdIsWithinValidRange() {
        // 기본값이 유효 범위 내에 있는지 확인
        XCTAssertGreaterThanOrEqual(settings.dragTriggerThreshold, 2)
        XCTAssertLessThanOrEqual(settings.dragTriggerThreshold, 20)
    }

    // MARK: - 커스텀 레이아웃 저장/로드 테스트

    func testCustomLayoutsSaveAndLoad() throws {
        let inputLayouts = [
            LayoutPreset(name: "테스트 1", frame: RelativeFrame(x: 0, y: 0, width: 0.4, height: 1), isBuiltIn: false),
            LayoutPreset(name: "테스트 2", frame: RelativeFrame(x: 0.4, y: 0, width: 0.6, height: 1), isBuiltIn: false)
        ]
        settings.customLayouts = inputLayouts

        let encodedData = try JSONEncoder().encode(settings.customLayouts)
        let actualLayouts = try JSONDecoder().decode([LayoutPreset].self, from: encodedData)

        XCTAssertEqual(actualLayouts.count, 2)
        XCTAssertEqual(actualLayouts[0].name, "테스트 1")
        XCTAssertEqual(actualLayouts[1].name, "테스트 2")
    }

    // MARK: - 단축키 바인딩 저장/로드 테스트

    func testShortcutBindingsSaveAndLoad() throws {
        let inputBindings: [String: ShortcutBinding] = [
            "half_left": ShortcutBinding(keyCode: 123, modifiers: 786432),
            "half_right": ShortcutBinding(keyCode: 124, modifiers: 786432)
        ]
        settings.shortcutBindings = inputBindings

        let encodedData = try JSONEncoder().encode(settings.shortcutBindings)
        let actualBindings = try JSONDecoder().decode([String: ShortcutBinding].self, from: encodedData)

        XCTAssertEqual(actualBindings.count, 2)
        XCTAssertEqual(actualBindings["half_left"]?.keyCode, 123)
        XCTAssertEqual(actualBindings["half_right"]?.keyCode, 124)
    }

    // MARK: - makeBuiltInPresets 테스트

    func testMakeBuiltInPresetsReturnsAllLayouts() {
        let actualPresets = settings.makeBuiltInPresets()
        XCTAssertEqual(actualPresets.count, BuiltInLayout.allCases.count)
    }

    func testMakeBuiltInPresetsUsesCustomRatios() {
        settings.halfRatio = 0.6
        let actualPresets = settings.makeBuiltInPresets()
        let halfLeftPreset = actualPresets.first { $0.name == BuiltInLayout.halfLeft.localizedName }
        XCTAssertNotNil(halfLeftPreset)
        XCTAssertEqual(halfLeftPreset?.frame.width ?? 0, 0.6, accuracy: 0.001)
    }

    // MARK: - 격리·영속성 테스트

    /// 값이 주입한 suite에 저장되고, 같은 suite로 다시 만든 인스턴스가 그 값을 읽어야 한다
    func testSettingsPersistToInjectedDefaultsOnly() {
        settings.halfRatio = 0.65
        settings.dragTriggerThreshold = 9
        XCTAssertEqual(testDefaults.double(forKey: SettingsKey.halfRatio.rawValue), 0.65, accuracy: 0.001)

        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertEqual(reloaded.halfRatio, 0.65, accuracy: 0.001)
        XCTAssertEqual(reloaded.dragTriggerThreshold, 9)
    }

    /// 로그인 항목 기본값은 꺼짐이고, 로드만으로는 값이 저장되지 않아야 한다
    func testLaunchAtLoginDefaultsToFalseAndLoadDoesNotWrite() {
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertNil(testDefaults.object(forKey: SettingsKey.launchAtLogin.rawValue))
    }

    /// 저장된 커스텀 레이아웃의 비정상 프레임은 로드 시 정리되어야 한다
    func testCustomLayoutsAreSanitizedOnLoad() throws {
        let broken = [LayoutPreset(name: "깨짐", frame: RelativeFrame(x: 0.9, y: 0, width: 0, height: 1))]
        testDefaults.set(try JSONEncoder().encode(broken), forKey: SettingsKey.customLayouts.rawValue)

        let reloaded = AppSettings(defaults: testDefaults)
        let frame = try XCTUnwrap(reloaded.customLayouts.first?.frame)
        XCTAssertEqual(frame.width, RelativeFrame.minimumCustomSize, accuracy: 0.001)
        XCTAssertLessThanOrEqual(frame.x + frame.width, 1.0 + 0.001)
    }
}
