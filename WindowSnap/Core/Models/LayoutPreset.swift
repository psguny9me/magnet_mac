import Foundation
import AppKit // NSEvent.ModifierFlags 사용을 위해 필요

// MARK: - RelativeFrame

/// 화면 대비 상대 비율로 표현한 창 프레임 (0.0 ~ 1.0)
struct RelativeFrame: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let zero = RelativeFrame(x: 0, y: 0, width: 0, height: 0)

    /// 절대 픽셀 좌표로 변환 (macOS는 좌하단 원점 사용)
    func toAbsoluteFrame(in screenFrame: CGRect) -> CGRect {
        let absoluteX = screenFrame.origin.x + x * screenFrame.width
        let absoluteY = screenFrame.origin.y + y * screenFrame.height
        let absoluteWidth = width * screenFrame.width
        let absoluteHeight = height * screenFrame.height
        return CGRect(x: absoluteX, y: absoluteY, width: absoluteWidth, height: absoluteHeight)
    }
}

// MARK: - ShortcutBinding

/// 키보드 단축키 바인딩 정보
struct ShortcutBinding: Codable, Equatable, Hashable {
    /// 키 코드 (가상 키 코드)
    var keyCode: UInt16
    /// 수식 키 플래그 (NSEvent.ModifierFlags.rawValue)
    var modifiers: UInt

    /// 표시용 문자열 (예: ⌃⌥←)
    var displayString: String {
        var result = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option)  { result += "⌥" }
        if flags.contains(.shift)   { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        result += KeyCodeHelper.displayString(for: keyCode)
        return result
    }
}

// MARK: - LayoutPreset

/// 창 배치 레이아웃 프리셋
struct LayoutPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    /// 화면 대비 상대 비율 프레임
    var frame: RelativeFrame
    /// 연결된 키보드 단축키 (없을 수 있음)
    var shortcut: ShortcutBinding?
    /// 기본 제공 프리셋 여부 (true면 삭제 불가)
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        frame: RelativeFrame,
        shortcut: ShortcutBinding? = nil,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.shortcut = shortcut
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - BuiltInLayout

/// 기본 제공 레이아웃 프리셋 정의 (16개)
enum BuiltInLayout: String, CaseIterable {
    case halfLeft       = "half_left"
    case halfRight      = "half_right"
    case halfTop        = "half_top"
    case halfBottom     = "half_bottom"
    case quarterTopLeft     = "quarter_tl"
    case quarterTopRight    = "quarter_tr"
    case quarterBottomLeft  = "quarter_bl"
    case quarterBottomRight = "quarter_br"
    case thirdLeft      = "third_left"
    case thirdCenter    = "third_center"
    case thirdRight     = "third_right"
    case twoThirdLeft   = "two_third_left"
    case twoThirdRight  = "two_third_right"
    case fullscreen     = "fullscreen"
    case center         = "center"
    case restore        = "restore"

    var localizedName: String {
        switch self {
        case .halfLeft:             return "좌측 절반"
        case .halfRight:            return "우측 절반"
        case .halfTop:              return "상단 절반"
        case .halfBottom:           return "하단 절반"
        case .quarterTopLeft:       return "좌측 상단 1/4"
        case .quarterTopRight:      return "우측 상단 1/4"
        case .quarterBottomLeft:    return "좌측 하단 1/4"
        case .quarterBottomRight:   return "우측 하단 1/4"
        case .thirdLeft:            return "좌측 1/3"
        case .thirdCenter:          return "중앙 1/3"
        case .thirdRight:           return "우측 1/3"
        case .twoThirdLeft:         return "좌측 2/3"
        case .twoThirdRight:        return "우측 2/3"
        case .fullscreen:           return "전체화면"
        case .center:               return "화면 중앙"
        case .restore:              return "원래 크기 복원"
        }
    }

    /// 기본 단축키 바인딩 (keyCode는 가상 키 코드)
    var defaultShortcut: ShortcutBinding? {
        let ctrlOpt: UInt = NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue
        switch self {
        case .halfLeft:             return ShortcutBinding(keyCode: 123, modifiers: ctrlOpt) // ←
        case .halfRight:            return ShortcutBinding(keyCode: 124, modifiers: ctrlOpt) // →
        case .halfTop:              return ShortcutBinding(keyCode: 126, modifiers: ctrlOpt) // ↑
        case .halfBottom:           return ShortcutBinding(keyCode: 125, modifiers: ctrlOpt) // ↓
        case .quarterTopLeft:       return ShortcutBinding(keyCode: 32,  modifiers: ctrlOpt) // U
        case .quarterTopRight:      return ShortcutBinding(keyCode: 34,  modifiers: ctrlOpt) // I
        case .quarterBottomLeft:    return ShortcutBinding(keyCode: 38,  modifiers: ctrlOpt) // J
        case .quarterBottomRight:   return ShortcutBinding(keyCode: 40,  modifiers: ctrlOpt) // K
        case .thirdLeft:            return ShortcutBinding(keyCode: 2,   modifiers: ctrlOpt) // D
        case .thirdCenter:          return ShortcutBinding(keyCode: 3,   modifiers: ctrlOpt) // F
        case .thirdRight:           return ShortcutBinding(keyCode: 5,   modifiers: ctrlOpt) // G
        case .twoThirdLeft:         return ShortcutBinding(keyCode: 14,  modifiers: ctrlOpt) // E
        case .twoThirdRight:        return ShortcutBinding(keyCode: 17,  modifiers: ctrlOpt) // T
        case .fullscreen:           return ShortcutBinding(keyCode: 36,  modifiers: ctrlOpt) // Return
        case .center:               return ShortcutBinding(keyCode: 8,   modifiers: ctrlOpt) // C
        case .restore:              return ShortcutBinding(keyCode: 51,  modifiers: ctrlOpt) // Delete
        }
    }

    /// 기본 RelativeFrame (비율은 AppSettings에서 커스터마이징 가능)
    func makeRelativeFrame(halfRatio: Double = 0.5, thirdRatio: Double = 1.0 / 3.0) -> RelativeFrame {
        let twoThird = 1.0 - thirdRatio
        switch self {
        case .halfLeft:             return RelativeFrame(x: 0,          y: 0,   width: halfRatio,  height: 1)
        case .halfRight:            return RelativeFrame(x: halfRatio,  y: 0,   width: 1 - halfRatio, height: 1)
        case .halfTop:              return RelativeFrame(x: 0,          y: 0.5, width: 1,          height: 0.5)
        case .halfBottom:           return RelativeFrame(x: 0,          y: 0,   width: 1,          height: 0.5)
        case .quarterTopLeft:       return RelativeFrame(x: 0,          y: 0.5, width: halfRatio,  height: 0.5)
        case .quarterTopRight:      return RelativeFrame(x: halfRatio,  y: 0.5, width: 1 - halfRatio, height: 0.5)
        case .quarterBottomLeft:    return RelativeFrame(x: 0,          y: 0,   width: halfRatio,  height: 0.5)
        case .quarterBottomRight:   return RelativeFrame(x: halfRatio,  y: 0,   width: 1 - halfRatio, height: 0.5)
        case .thirdLeft:            return RelativeFrame(x: 0,          y: 0,   width: thirdRatio, height: 1)
        case .thirdCenter:          return RelativeFrame(x: thirdRatio, y: 0,   width: thirdRatio, height: 1)
        case .thirdRight:           return RelativeFrame(x: twoThird,   y: 0,   width: thirdRatio, height: 1)
        case .twoThirdLeft:         return RelativeFrame(x: 0,          y: 0,   width: twoThird,   height: 1)
        case .twoThirdRight:        return RelativeFrame(x: thirdRatio, y: 0,   width: twoThird,   height: 1)
        case .fullscreen:           return RelativeFrame(x: 0,          y: 0,   width: 1,          height: 1)
        case .center:               return RelativeFrame(x: 0,          y: 0,   width: 0,          height: 0) // 특수: 크기 유지
        case .restore:              return RelativeFrame(x: 0,          y: 0,   width: 0,          height: 0) // 특수: 복원
        }
    }

    /// 기본 LayoutPreset으로 변환
    func makeLayoutPreset(halfRatio: Double = 0.5, thirdRatio: Double = 1.0 / 3.0) -> LayoutPreset {
        LayoutPreset(
            name: localizedName,
            frame: makeRelativeFrame(halfRatio: halfRatio, thirdRatio: thirdRatio),
            shortcut: defaultShortcut,
            isBuiltIn: true
        )
    }
}

// MARK: - KeyCodeHelper

/// 가상 키 코드를 표시용 문자열로 변환하는 헬퍼
enum KeyCodeHelper {
    static func displayString(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0:  return "A"
        case 1:  return "S"
        case 2:  return "D"
        case 3:  return "F"
        case 4:  return "H"
        case 5:  return "G"
        case 6:  return "Z"
        case 7:  return "X"
        case 8:  return "C"
        case 9:  return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 36: return "↩"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "(\(keyCode))"
        }
    }
}
