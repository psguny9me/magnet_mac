import XCTest

// MARK: - ClipboardFileNamingTests

/// 클립보드 이미지 파일명 생성 로직 단위 테스트
final class ClipboardFileNamingTests: XCTestCase {

    // MARK: - 기본 파일명 생성 테스트

    func testFileNameFormat() {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 20
        components.hour = 19
        components.minute = 5
        components.second = 3
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        let name = ClipboardFileNaming.fileName(for: date)

        XCTAssertEqual(name, "클립보드 2026-07-20 19.05.03.png")
    }

    // MARK: - 고유 이름 생성 테스트

    func testUniqueFileNameReturnsBaseWhenNoConflict() {
        let base = "클립보드 2026-07-20 19.05.03.png"
        let result = ClipboardFileNaming.uniqueFileName(base: base, existing: [])
        XCTAssertEqual(result, base)
    }

    func testUniqueFileNameAppendsIndexOnConflict() {
        let base = "클립보드 2026-07-20 19.05.03.png"
        let result = ClipboardFileNaming.uniqueFileName(base: base, existing: [base])
        XCTAssertEqual(result, "클립보드 2026-07-20 19.05.03 (2).png")
    }

    func testUniqueFileNameSkipsExistingIndexes() {
        let base = "클립보드 2026-07-20 19.05.03.png"
        let existing: Set<String> = [
            base,
            "클립보드 2026-07-20 19.05.03 (2).png",
            "클립보드 2026-07-20 19.05.03 (3).png"
        ]
        let result = ClipboardFileNaming.uniqueFileName(base: base, existing: existing)
        XCTAssertEqual(result, "클립보드 2026-07-20 19.05.03 (4).png")
    }
}
