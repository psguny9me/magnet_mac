import XCTest

// MARK: - LayoutPresetTests

/// LayoutPreset Codable 직렬화/역직렬화 단위 테스트
final class LayoutPresetTests: XCTestCase {

    // MARK: - RelativeFrame 테스트

    func testRelativeFrameEncodeAndDecode() throws {
        let inputFrame = RelativeFrame(x: 0.1, y: 0.2, width: 0.5, height: 0.8)
        let encodedData = try JSONEncoder().encode(inputFrame)
        let actualFrame = try JSONDecoder().decode(RelativeFrame.self, from: encodedData)
        XCTAssertEqual(inputFrame, actualFrame)
    }

    // MARK: - ShortcutBinding 테스트

    func testShortcutBindingEncodeAndDecode() throws {
        let inputShortcut = ShortcutBinding(keyCode: 123, modifiers: 786432)
        let encodedData = try JSONEncoder().encode(inputShortcut)
        let actualShortcut = try JSONDecoder().decode(ShortcutBinding.self, from: encodedData)
        XCTAssertEqual(inputShortcut, actualShortcut)
    }

    func testShortcutBindingDisplayString() {
        let ctrlOpt: UInt = NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue
        let inputShortcut = ShortcutBinding(keyCode: 123, modifiers: ctrlOpt) // ⌃⌥←
        XCTAssertTrue(inputShortcut.displayString.contains("⌃"))
        XCTAssertTrue(inputShortcut.displayString.contains("⌥"))
        XCTAssertTrue(inputShortcut.displayString.contains("←"))
    }

    // MARK: - LayoutPreset 테스트

    func testLayoutPresetEncodeAndDecode() throws {
        let inputPreset = LayoutPreset(
            id: UUID(),
            name: "테스트 레이아웃",
            frame: RelativeFrame(x: 0, y: 0, width: 0.5, height: 1),
            shortcut: ShortcutBinding(keyCode: 123, modifiers: 786432),
            isBuiltIn: false
        )
        let encodedData = try JSONEncoder().encode(inputPreset)
        let actualPreset = try JSONDecoder().decode(LayoutPreset.self, from: encodedData)
        XCTAssertEqual(actualPreset.id, inputPreset.id)
        XCTAssertEqual(actualPreset.name, inputPreset.name)
        XCTAssertEqual(actualPreset.frame, inputPreset.frame)
        XCTAssertEqual(actualPreset.isBuiltIn, inputPreset.isBuiltIn)
    }

    func testLayoutPresetArrayEncodeAndDecode() throws {
        let inputLayouts = BuiltInLayout.allCases.map { $0.makeLayoutPreset() }
        let encodedData = try JSONEncoder().encode(inputLayouts)
        let actualLayouts = try JSONDecoder().decode([LayoutPreset].self, from: encodedData)
        XCTAssertEqual(inputLayouts.count, actualLayouts.count)
        for (expected, actual) in zip(inputLayouts, actualLayouts) {
            XCTAssertEqual(expected.name, actual.name)
            XCTAssertEqual(expected.isBuiltIn, actual.isBuiltIn)
        }
    }

    // MARK: - BuiltInLayout 테스트

    func testBuiltInLayoutCount() {
        XCTAssertEqual(BuiltInLayout.allCases.count, 19)
    }

    func testAllBuiltInLayoutsHaveDefaultShortcuts() {
        for layout in BuiltInLayout.allCases {
            XCTAssertNotNil(layout.defaultShortcut, "\(layout) should have a default shortcut")
        }
    }

    func testHalfRatioCustomization() {
        let customHalfRatio = 0.6
        let preset = BuiltInLayout.halfLeft.makeLayoutPreset(halfRatio: customHalfRatio)
        XCTAssertEqual(preset.frame.width, customHalfRatio, accuracy: 0.001)
    }

    func testThirdRatioCustomization() {
        let customThirdRatio = 0.3
        let preset = BuiltInLayout.thirdLeft.makeLayoutPreset(thirdRatio: customThirdRatio)
        XCTAssertEqual(preset.frame.width, customThirdRatio, accuracy: 0.001)
    }

    // MARK: - KeyCodeHelper 테스트

    func testKeyCodeDisplayStrings() {
        XCTAssertEqual(KeyCodeHelper.displayString(for: 123), "←")
        XCTAssertEqual(KeyCodeHelper.displayString(for: 124), "→")
        XCTAssertEqual(KeyCodeHelper.displayString(for: 125), "↓")
        XCTAssertEqual(KeyCodeHelper.displayString(for: 126), "↑")
        XCTAssertEqual(KeyCodeHelper.displayString(for: 36), "↩")
        XCTAssertEqual(KeyCodeHelper.displayString(for: 51), "⌫")
    }
}
