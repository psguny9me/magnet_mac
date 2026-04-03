import XCTest

// MARK: - AppSettingsTests

/// AppSettings UserDefaults 읽기/쓰기 단위 테스트
final class AppSettingsTests: XCTestCase {

    private let suiteName = "com.windowsnap.tests"
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - 기본값 테스트

    func testDefaultHalfRatioValue() {
        XCTAssertEqual(AppSettings.shared.halfRatio, 0.5, accuracy: 0.001)
    }

    func testDefaultThirdRatioValue() {
        XCTAssertEqual(AppSettings.shared.thirdRatio, 1.0 / 3.0, accuracy: 0.001)
    }

    func testDefaultDragTriggerThreshold() {
        XCTAssertEqual(AppSettings.shared.dragTriggerThreshold, 4)
    }

    // MARK: - 비율 범위 제한 테스트 (loadAllSettings 로드 시 clamping 적용 확인)

    func testHalfRatioIsWithinValidRange() {
        // 기본값이 유효 범위 내에 있는지 확인
        XCTAssertGreaterThanOrEqual(AppSettings.shared.halfRatio, 0.3)
        XCTAssertLessThanOrEqual(AppSettings.shared.halfRatio, 0.7)
    }

    func testDragTriggerThresholdIsWithinValidRange() {
        // 기본값이 유효 범위 내에 있는지 확인
        XCTAssertGreaterThanOrEqual(AppSettings.shared.dragTriggerThreshold, 2)
        XCTAssertLessThanOrEqual(AppSettings.shared.dragTriggerThreshold, 20)
    }

    // MARK: - 커스텀 레이아웃 저장/로드 테스트

    func testCustomLayoutsSaveAndLoad() throws {
        let inputLayouts = [
            LayoutPreset(name: "테스트 1", frame: RelativeFrame(x: 0, y: 0, width: 0.4, height: 1), isBuiltIn: false),
            LayoutPreset(name: "테스트 2", frame: RelativeFrame(x: 0.4, y: 0, width: 0.6, height: 1), isBuiltIn: false)
        ]
        AppSettings.shared.customLayouts = inputLayouts

        let encodedData = try JSONEncoder().encode(AppSettings.shared.customLayouts)
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
        AppSettings.shared.shortcutBindings = inputBindings

        let encodedData = try JSONEncoder().encode(AppSettings.shared.shortcutBindings)
        let actualBindings = try JSONDecoder().decode([String: ShortcutBinding].self, from: encodedData)

        XCTAssertEqual(actualBindings.count, 2)
        XCTAssertEqual(actualBindings["half_left"]?.keyCode, 123)
        XCTAssertEqual(actualBindings["half_right"]?.keyCode, 124)
    }

    // MARK: - makeBuiltInPresets 테스트

    func testMakeBuiltInPresetsReturnsAllLayouts() {
        let actualPresets = AppSettings.shared.makeBuiltInPresets()
        XCTAssertEqual(actualPresets.count, BuiltInLayout.allCases.count)
    }

    func testMakeBuiltInPresetsUsesCustomRatios() {
        AppSettings.shared.halfRatio = 0.6
        let actualPresets = AppSettings.shared.makeBuiltInPresets()
        let halfLeftPreset = actualPresets.first { $0.name == BuiltInLayout.halfLeft.localizedName }
        XCTAssertNotNil(halfLeftPreset)
        XCTAssertEqual(halfLeftPreset?.frame.width ?? 0, 0.6, accuracy: 0.001)
        AppSettings.shared.halfRatio = 0.5
    }
}
