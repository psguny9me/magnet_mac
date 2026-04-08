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

    func testPortraitRotationSwapsWidthAndHeight() {
        let originalFrame = RelativeFrame(x: 0, y: 0, width: 0.5, height: 1.0)
        let rotatedFrame = calculator.rotateFrameForPortrait(originalFrame)
        XCTAssertEqual(rotatedFrame.width, originalFrame.height)
        XCTAssertEqual(rotatedFrame.height, originalFrame.width)
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
