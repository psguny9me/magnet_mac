import SwiftUI

// MARK: - AdvancedView

/// 고급 설정 탭 뷰
struct AdvancedView: View {

    @State private var settings = AppSettings.shared
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    var body: some View {
        Form {
            Section("레이아웃 비율 커스터마이징") {
                HStack {
                    Text("절반 분할 비율")
                    Spacer()
                    Slider(value: $settings.halfRatio, in: 0.3...0.7, step: 0.05)
                        .frame(width: 200)
                    Text(String(format: "%.0f%%", settings.halfRatio * 100))
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack {
                    Text("1/3 분할 비율")
                    Spacer()
                    Slider(value: $settings.thirdRatio, in: 0.2...0.45, step: 0.01)
                        .frame(width: 200)
                    Text(String(format: "%.0f%%", settings.thirdRatio * 100))
                        .frame(width: 40, alignment: .trailing)
                        .monospacedDigit()
                }

                Button("비율 기본값으로 초기화") {
                    settings.halfRatio = 0.5
                    settings.thirdRatio = 1.0 / 3.0
                }
                .buttonStyle(.borderless)
            }

            Section("접근성 권한") {
                HStack {
                    Circle()
                        .fill(isAccessibilityGranted ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(isAccessibilityGranted ? "접근성 권한이 허용되었습니다." : "접근성 권한이 필요합니다.")
                        .foregroundStyle(isAccessibilityGranted ? Color.primary : Color.red)
                    Spacer()
                    if !isAccessibilityGranted {
                        Button("시스템 설정 열기") {
                            openAccessibilitySettings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if !isAccessibilityGranted {
                    Text("접근성 권한이 없으면 창 이동, 단축키 기능을 사용할 수 없습니다.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            Section("앱 정보") {
                LabeledContent("버전", value: appVersion)
                LabeledContent("타겟 OS", value: "macOS 14.0+")
                LabeledContent("아키텍처", value: "Apple Silicon (arm64)")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            checkAccessibilityPermission()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            checkAccessibilityPermission()
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func checkAccessibilityPermission() {
        isAccessibilityGranted = AXIsProcessTrusted()
        if isAccessibilityGranted {
            MenuBarController.shared.showNormalIcon()
        } else {
            MenuBarController.shared.showAccessibilityWarning()
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url {
            NSWorkspace.shared.open(url)
        }
    }
}
