import AppKit

// MARK: - ClipboardImageSaveError

/// 클립보드 이미지 저장 오류
enum ClipboardImageSaveError: Error, LocalizedError {
    case noImageInClipboard
    case encodingFailed
    case writeFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noImageInClipboard:
            return "클립보드에 이미지가 없습니다."
        case .encodingFailed:
            return "이미지를 PNG로 변환하지 못했습니다."
        case .writeFailed(let underlying):
            return "파일 저장 실패: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - ClipboardImageSaver

/// 클립보드의 이미지를 PNG 파일로 저장 (메인 스레드 전용)
@MainActor
final class ClipboardImageSaver {

    // MARK: - Singleton

    @MainActor static let shared = ClipboardImageSaver()

    private init() {}

    // MARK: - Public API

    /// 클립보드 이미지를 설정된 폴더에 저장하고 결과를 토스트로 알림
    func saveClipboardImage() {
        do {
            let savedURL = try saveImageFromPasteboard()
            ToastWindow.shared.show(message: "이미지 저장됨: \(savedURL.lastPathComponent)")
            NSSound(named: "Pop")?.play()
        } catch {
            ToastWindow.shared.show(message: error.localizedDescription)
        }
    }

    /// 현재 설정 기준 저장 폴더 URL (~ 확장 포함)
    func saveDirectoryURL() -> URL {
        let rawPath = AppSettings.shared.clipboardSaveDirectoryPath
        let expanded = (rawPath as NSString).expandingTildeInPath
        guard !expanded.isEmpty else {
            return URL(fileURLWithPath: AppSettings.defaultClipboardSaveDirectoryPath, isDirectory: true)
        }
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }

    // MARK: - Private Helpers

    private func saveImageFromPasteboard() throws -> URL {
        let pngData = try pngDataFromPasteboard()
        let directory = saveDirectoryURL()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let existingNames = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let baseName = ClipboardFileNaming.fileName(for: Date())
        let fileName = ClipboardFileNaming.uniqueFileName(base: baseName, existing: Set(existingNames))
        let fileURL = directory.appendingPathComponent(fileName)

        do {
            try pngData.write(to: fileURL, options: .atomic)
        } catch {
            throw ClipboardImageSaveError.writeFailed(underlying: error)
        }
        return fileURL
    }

    private func pngDataFromPasteboard() throws -> Data {
        let pasteboard = NSPasteboard.general

        // 1) PNG 데이터가 그대로 있으면 무변환 저장
        if let pngData = pasteboard.data(forType: .png) {
            return pngData
        }

        // 2) TIFF·파일 복사 등 다른 표현은 NSImage로 읽어 PNG로 변환
        guard let image = NSImage(pasteboard: pasteboard),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw ClipboardImageSaveError.noImageInClipboard
        }
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ClipboardImageSaveError.encodingFailed
        }
        return pngData
    }
}
