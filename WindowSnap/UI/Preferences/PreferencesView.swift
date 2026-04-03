import SwiftUI

// MARK: - PreferenceTab

/// 설정 패널 탭 목록
enum PreferenceTab: String, CaseIterable {
    case general    = "일반"
    case shortcuts  = "단축키"
    case layouts    = "레이아웃"
    case advanced   = "고급"

    var systemImage: String {
        switch self {
        case .general:   return "gearshape"
        case .shortcuts: return "keyboard"
        case .layouts:   return "rectangle.3.group"
        case .advanced:  return "slider.horizontal.3"
        }
    }
}

// MARK: - PreferencesView

/// 설정 패널 메인 뷰 (4개 탭)
struct PreferencesView: View {

    @State private var selectedTab: PreferenceTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralView()
                .tabItem {
                    Label(PreferenceTab.general.rawValue, systemImage: PreferenceTab.general.systemImage)
                }
                .tag(PreferenceTab.general)

            ShortcutsView()
                .tabItem {
                    Label(PreferenceTab.shortcuts.rawValue, systemImage: PreferenceTab.shortcuts.systemImage)
                }
                .tag(PreferenceTab.shortcuts)

            LayoutsView()
                .tabItem {
                    Label(PreferenceTab.layouts.rawValue, systemImage: PreferenceTab.layouts.systemImage)
                }
                .tag(PreferenceTab.layouts)

            AdvancedView()
                .tabItem {
                    Label(PreferenceTab.advanced.rawValue, systemImage: PreferenceTab.advanced.systemImage)
                }
                .tag(PreferenceTab.advanced)
        }
        .frame(width: 560, height: 440)
    }
}
