import AppKit
import XCTest

// MARK: - SnapCalculatorTests

/// SnapCalculator 좌표 계산 단위 테스트
final class SnapCalculatorTests: XCTestCase {

    private let calculator = SnapCalculator.shared
    private let settings = AppSettings.shared

    // MARK: - 기본 프리셋 프레임 계산 테스트

    func testHalfLeftFrameCalculation() {
        let preset = BuiltInLayout.halfLeft.makeLayoutPreset()
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let actualFrame = preset.frame.toAbsoluteFrame(in: screenFrame)

        XCTAssertEqual(actualFrame.origin.x, 0)
        XCTAssertEqual(actualFrame.origin.y, 0)
        XCTAssertEqual(actualFrame.width, 500)
        XCTAssertEqual(actualFrame.height, 800)
    }

    func testHalfRightFrameCalculation() {
        let preset = BuiltInLayout.halfRight.makeLayoutPreset()
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let actualFrame = preset.frame.toAbsoluteFrame(in: screenFrame)

        XCTAssertEqual(actualFrame.origin.x, 500)
        XCTAssertEqual(actualFrame.width, 500)
        XCTAssertEqual(actualFrame.height, 800)
    }

    func testFullscreenFrameCalculation() {
        let preset = BuiltInLayout.fullscreen.makeLayoutPreset()
        let screenFrame = CGRect(x: 0, y: 0, width: 2000, height: 1200)
        let actualFrame = preset.frame.toAbsoluteFrame(in: screenFrame)

        XCTAssertEqual(actualFrame, screenFrame)
    }

    func testQuarterTopLeftFrameCalculation() {
        let preset = BuiltInLayout.quarterTopLeft.makeLayoutPreset()
        let screenFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let actualFrame = preset.frame.toAbsoluteFrame(in: screenFrame)

        XCTAssertEqual(actualFrame.width, 500)
        XCTAssertEqual(actualFrame.height, 400)
    }

    func testThirdLeftFrameCalculation() {
        let preset = BuiltInLayout.thirdLeft.makeLayoutPreset(thirdRatio: 1.0 / 3.0)
        let screenFrame = CGRect(x: 0, y: 0, width: 900, height: 600)
        let actualFrame = preset.frame.toAbsoluteFrame(in: screenFrame)

        XCTAssertEqual(actualFrame.width, 300, accuracy: 1)
        XCTAssertEqual(actualFrame.height, 600)
    }

    func testAllBuiltInLayoutsHaveNonZeroFrames() {
        let specialLayouts: Set<BuiltInLayout> = [.center, .restore, .moveToMonitor1, .moveToMonitor2, .moveToMonitor3]
        for layout in BuiltInLayout.allCases {
            guard !specialLayouts.contains(layout) else { continue }
            let preset = layout.makeLayoutPreset()
            XCTAssertGreaterThan(preset.frame.width, 0, "\(layout) width should be > 0")
            XCTAssertGreaterThan(preset.frame.height, 0, "\(layout) height should be > 0")
        }
    }

    // MARK: - 세로형 모니터 회전 테스트

    /// 메뉴바 제외와 Dock 제외가 서로 독립적으로 적용되어야 한다 (frame 1000x800, 메뉴바 25pt, 하단 Dock 70pt)
    func testUsableFrameAppliesMenuBarAndDockInsetsIndependently() {
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let visible = CGRect(x: 0, y: 70, width: 1000, height: 705)

        let menuBarOnly = calculator.usableFrame(frame: frame, visibleFrame: visible, ignoreMenuBar: true, ignoreDock: false)
        XCTAssertEqual(menuBarOnly, CGRect(x: 0, y: 0, width: 1000, height: 775))

        let dockOnly = calculator.usableFrame(frame: frame, visibleFrame: visible, ignoreMenuBar: false, ignoreDock: true)
        XCTAssertEqual(dockOnly, CGRect(x: 0, y: 70, width: 1000, height: 730))

        let both = calculator.usableFrame(frame: frame, visibleFrame: visible, ignoreMenuBar: true, ignoreDock: true)
        XCTAssertEqual(both, visible)

        let neither = calculator.usableFrame(frame: frame, visibleFrame: visible, ignoreMenuBar: false, ignoreDock: false)
        XCTAssertEqual(neither, frame)
    }

    /// Menu-bar Y reference: BL global screen.frame -> AX -> BL global round-trips for `NSScreen.main`
    func testBottomLeftGlobalToAXRoundTripForMainScreenFrame() {
        guard let mainScreen = NSScreen.main else {
            XCTFail("NSScreen.main required")
            return
        }
        let inputBottomLeftGlobal = mainScreen.frame
        let axRect = calculator.convertToTopLeftOrigin(frame: inputBottomLeftGlobal, screen: mainScreen)
        let outputBottomLeftGlobal = calculator.convertAXFrameToBottomLeftGlobal(axRect)
        XCTAssertEqual(outputBottomLeftGlobal.origin.x, inputBottomLeftGlobal.origin.x, accuracy: 0.01)
        XCTAssertEqual(outputBottomLeftGlobal.origin.y, inputBottomLeftGlobal.origin.y, accuracy: 0.01)
        XCTAssertEqual(outputBottomLeftGlobal.width, inputBottomLeftGlobal.width, accuracy: 0.01)
        XCTAssertEqual(outputBottomLeftGlobal.height, inputBottomLeftGlobal.height, accuracy: 0.01)
    }

    // MARK: - 상하 방향 회귀 테스트 (AX 좌상단 프레임 기준, y=0이 화면 위쪽)

    /// 메뉴바 25pt를 제외한 LG 4K 가용 영역을 AX 좌표로 표현한 값
    private let axScreenFrame = CGRect(x: 0, y: 25, width: 3360, height: 1865)

    func testHalfTopIsPlacedAtTopOfScreen() {
        let frame = BuiltInLayout.halfTop.makeLayoutPreset().frame.toAbsoluteFrame(in: axScreenFrame)
        XCTAssertEqual(frame.minY, axScreenFrame.minY, accuracy: 0.01)
        XCTAssertEqual(frame.height, axScreenFrame.height / 2, accuracy: 0.01)
    }

    func testHalfBottomIsPlacedAtBottomOfScreen() {
        let frame = BuiltInLayout.halfBottom.makeLayoutPreset().frame.toAbsoluteFrame(in: axScreenFrame)
        XCTAssertEqual(frame.minY, axScreenFrame.midY, accuracy: 0.01)
        XCTAssertEqual(frame.maxY, axScreenFrame.maxY, accuracy: 0.01)
    }

    func testQuarterTopLeftIsPlacedAtTopLeftCorner() {
        let frame = BuiltInLayout.quarterTopLeft.makeLayoutPreset().frame.toAbsoluteFrame(in: axScreenFrame)
        XCTAssertEqual(frame.origin.x, axScreenFrame.minX, accuracy: 0.01)
        XCTAssertEqual(frame.origin.y, axScreenFrame.minY, accuracy: 0.01)
    }

    func testQuarterBottomRightIsPlacedAtBottomRightCorner() {
        let frame = BuiltInLayout.quarterBottomRight.makeLayoutPreset().frame.toAbsoluteFrame(in: axScreenFrame)
        XCTAssertEqual(frame.maxX, axScreenFrame.maxX, accuracy: 0.01)
        XCTAssertEqual(frame.maxY, axScreenFrame.maxY, accuracy: 0.01)
    }

    // MARK: - AX 원점 기준 테스트 (주 화면 = NSScreen.screens[0])

    /// 주 화면 프레임의 AX 변환 결과는 원점 (0,0)이어야 한다. 키보드 포커스 화면(NSScreen.main)과 무관해야 한다
    func testPrimaryScreenFrameConvertsToAXOrigin() throws {
        let primary = try XCTUnwrap(NSScreen.screens.first)
        let axRect = calculator.convertToTopLeftOrigin(frame: primary.frame, screen: primary)
        XCTAssertEqual(axRect.origin.x, 0, accuracy: 0.01)
        XCTAssertEqual(axRect.origin.y, 0, accuracy: 0.01)
    }

    /// 주 화면 아래쪽에 놓인 보조 화면(예: 좌하단 글로벌 y가 음수)은 AX y가 주 화면 높이보다 커야 한다
    func testSecondaryScreenBelowPrimaryConvertsBelowInAXSpace() throws {
        let primary = try XCTUnwrap(NSScreen.screens.first)
        let secondaryBottomLeft = CGRect(x: 100, y: -600, width: 800, height: 600) // 주 화면 바로 아래
        let axRect = calculator.convertToTopLeftOrigin(frame: secondaryBottomLeft, screen: primary)
        XCTAssertEqual(axRect.origin.y, primary.frame.maxY, accuracy: 0.01)
        XCTAssertEqual(axRect.origin.x, 100, accuracy: 0.01)
    }

}

// MARK: - SnapCalculator Trigger Zone Tests (requires NSScreen)

final class SnapCalculatorTriggerTests: XCTestCase {

    private let calculator = SnapCalculator.shared

    func testLeftEdgeTriggerDetection() {
        guard let screen = NSScreen.main else { return }
        let mouseAt = CGPoint(x: screen.frame.minX + 2, y: screen.frame.midY)
        let actualZone = calculator.detectTriggerZone(at: mouseAt, on: screen, threshold: 4)
        XCTAssertEqual(actualZone, .leftEdge)
    }

    func testNoTriggerZoneInCenter() {
        guard let screen = NSScreen.main else { return }
        let mouseAt = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
        let actualZone = calculator.detectTriggerZone(at: mouseAt, on: screen, threshold: 4)
        XCTAssertNil(actualZone)
    }
}
