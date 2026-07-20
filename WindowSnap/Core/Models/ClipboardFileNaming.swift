import Foundation

// MARK: - ClipboardFileNaming

/// 클립보드 이미지 저장 파일명 생성 (순수 로직)
enum ClipboardFileNaming {

    /// 저장 시각 기반 기본 파일명 (예: "클립보드 2026-07-20 19.15.30.png")
    static func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "클립보드 \(formatter.string(from: date)).png"
    }

    /// 동일 이름이 이미 존재하면 " (2)", " (3)"…을 붙여 고유 이름 반환
    static func uniqueFileName(base: String, existing: Set<String>) -> String {
        guard existing.contains(base) else { return base }
        let stem = (base as NSString).deletingPathExtension
        let ext = (base as NSString).pathExtension
        var index = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem) (\(index))" : "\(stem) (\(index)).\(ext)"
            if !existing.contains(candidate) { return candidate }
            index += 1
        }
    }
}
