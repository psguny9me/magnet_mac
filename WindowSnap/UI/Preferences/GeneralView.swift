import SwiftUI

// MARK: - GeneralView

/// 일반 설정 탭 뷰
struct GeneralView: View {

    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("실행") {
                Toggle("로그인 시 자동 실행", isOn: $settings.launchAtLogin)
                Toggle("메뉴바 아이콘 표시", isOn: $settings.showMenuBarIcon)
                    .onChange(of: settings.showMenuBarIcon) { _, newValue in
                        handleMenuBarVisibility(isVisible: newValue)
                    }
            }

            Section("드래그 트리거") {
                Toggle("드래그 트리거 활성화", isOn: $settings.dragTriggerEnabled)
                    .onChange(of: settings.dragTriggerEnabled) { _, isDragTriggerEnabled in
                        if isDragTriggerEnabled, AXIsProcessTrusted() {
                            DragMonitor.shared.startMonitoring()
                        } else if !isDragTriggerEnabled {
                            DragMonitor.shared.stopMonitoring()
                        }
                    }

                if settings.dragTriggerEnabled {
                    HStack {
                        Text("감지 임계값")
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { Double(settings.dragTriggerThreshold) },
                                set: { settings.dragTriggerThreshold = Int($0) }
                            ),
                            in: 2...20,
                            step: 1
                        )
                        .frame(width: 200)
                        Text("\(settings.dragTriggerThreshold)px")
                            .frame(width: 35, alignment: .trailing)
                            .monospacedDigit()
                    }

                    Toggle("스냅 미리보기 표시", isOn: $settings.snapPreviewEnabled)
                }
            }

            Section("클립보드 이미지 저장") {
                HStack {
                    Text("저장 폴더")
                    Spacer()
                    Text((settings.clipboardSaveDirectoryPath as NSString).abbreviatingWithTildeInPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("변경...") { chooseClipboardSaveDirectory() }
                }
                Text("단축키는 단축키 탭의 '클립보드 이미지 저장' 항목에서 변경할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("기타") {
                Toggle("Green Button 팝오버 메뉴", isOn: $settings.greenButtonMenuEnabled)
                Toggle("전체화면 시 메뉴바 공간 제외", isOn: $settings.ignoreMenuBar)
                Toggle("레이아웃 계산 시 Dock 공간 제외", isOn: $settings.ignoreDock)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func chooseClipboardSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: settings.clipboardSaveDirectoryPath, isDirectory: true)
        if panel.runModal() == .OK, let url = panel.url {
            settings.clipboardSaveDirectoryPath = url.path
        }
    }

    private func handleMenuBarVisibility(isVisible: Bool) {
        if isVisible {
            MenuBarController.shared.setupMenuBar()
        } else {
            MenuBarController.shared.removeMenuBar()
        }
    }
}
