import SwiftUI

// MARK: - LayoutsView

/// 커스텀 레이아웃 추가/편집/삭제 탭 뷰
struct LayoutsView: View {

    @State private var settings = AppSettings.shared
    @State private var isAddingLayout: Bool = false
    @State private var editingLayout: LayoutPreset? = nil
    @State private var selectedLayoutId: UUID? = nil

    var body: some View {
        HSplitView {
            layoutList
                .frame(minWidth: 200, maxWidth: 220)

            layoutEditor
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Layout List

    private var layoutList: some View {
        VStack(spacing: 0) {
            List(settings.customLayouts, selection: $selectedLayoutId) { layout in
                Text(layout.name)
                    .tag(layout.id)
            }

            Divider()

            HStack(spacing: 4) {
                Button(action: { isAddingLayout = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                Button(action: deleteSelectedLayout) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedLayoutId == nil)

                Spacer()
            }
            .padding(6)
        }
        .sheet(isPresented: $isAddingLayout) {
            LayoutEditSheet(mode: .add) { newLayout in
                var sanitized = newLayout
                sanitized.frame = newLayout.frame.sanitized()
                settings.customLayouts.append(sanitized)
                reloadShortcuts()
            }
        }
    }

    // MARK: - Layout Editor

    private var layoutEditor: some View {
        Group {
            if let id = selectedLayoutId,
               let index = settings.customLayouts.firstIndex(where: { $0.id == id }) {
                LayoutDetailEditor(
                    layout: $settings.customLayouts[index],
                    onSave: reloadShortcuts
                )
            } else {
                VStack {
                    Spacer()
                    Text("레이아웃을 선택하거나 + 버튼으로 새로 추가하세요.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteSelectedLayout() {
        guard let id = selectedLayoutId else { return }
        settings.customLayouts.removeAll { $0.id == id }
        selectedLayoutId = nil
        reloadShortcuts()
    }

    private func reloadShortcuts() {
        let presets = settings.makeBuiltInPresets() + settings.customLayouts
        KeyboardShortcutManager.shared.registerShortcuts(from: presets)
        MenuBarController.shared.rebuildMenu()
    }
}

// MARK: - LayoutDetailEditor

/// 선택된 커스텀 레이아웃의 세부 정보 편집 뷰
private struct LayoutDetailEditor: View {

    @Binding var layout: LayoutPreset
    let onSave: () -> Void

    @State private var isRecordingShortcut = false
    @State private var shortcutError: String? = nil

    var body: some View {
        Form {
            Section("레이아웃 정보") {
                TextField("이름", text: $layout.name)

                LabeledContent("단축키") {
                    shortcutEditor
                }
                if let shortcutError {
                    Text(shortcutError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                LabeledContent("X 위치") {
                    ratioSlider(value: $layout.frame.x, label: "X")
                }
                LabeledContent("Y 위치") {
                    ratioSlider(value: $layout.frame.y, label: "Y")
                }
                LabeledContent("너비") {
                    ratioSlider(value: $layout.frame.width, label: "너비")
                }
                LabeledContent("높이") {
                    ratioSlider(value: $layout.frame.height, label: "높이")
                }
            }

            Section("미리보기") {
                LayoutPreviewView(frame: layout.frame)
                    .frame(height: 120)
            }
        }
        .formStyle(.grouped)
        .onChange(of: layout) { _, newValue in
            // 슬라이더가 만든 비정상 프레임(크기 0, 화면 밖)은 즉시 정리한다
            let sanitized = newValue.frame.sanitized()
            if sanitized != newValue.frame {
                layout.frame = sanitized
                return
            }
            onSave()
        }
    }

    /// 커스텀 레이아웃 단축키 편집 (내장 레이아웃과 같은 녹화기·충돌 검사 사용)
    private var shortcutEditor: some View {
        HStack {
            if isRecordingShortcut {
                ShortcutRecorderView(
                    onRecord: { newShortcut in
                        do {
                            try KeyboardShortcutManager.shared.validateShortcut(
                                newShortcut,
                                excludingKey: layout.bindingKey
                            )
                            layout.shortcut = newShortcut
                            shortcutError = nil
                        } catch {
                            shortcutError = error.localizedDescription
                        }
                        isRecordingShortcut = false
                    },
                    onCancel: { isRecordingShortcut = false }
                )
                .frame(width: 150, height: 22)
            } else {
                Text(layout.shortcut?.displayString ?? "없음")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(layout.shortcut == nil ? .tertiary : .primary)
                    .frame(width: 150)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onTapGesture { isRecordingShortcut = true }
            }

            Button {
                layout.shortcut = nil
                shortcutError = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(layout.shortcut != nil ? 1 : 0)
        }
    }

    private func ratioSlider(value: Binding<Double>, label: String) -> some View {
        HStack {
            Slider(value: value, in: 0...1, step: 0.01)
                .frame(width: 180)
            Text(String(format: "%.0f%%", value.wrappedValue * 100))
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

// MARK: - LayoutPreviewView

/// 레이아웃 프레임 비율을 시각적으로 미리보기하는 뷰
private struct LayoutPreviewView: View {

    let frame: RelativeFrame

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // 화면 배경
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )

                // 창 영역
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                    .frame(
                        width: geo.size.width * frame.width,
                        height: geo.size.height * frame.height
                    )
                    .offset(
                        x: geo.size.width * frame.x,
                        y: geo.size.height * frame.y
                    )
            }
        }
        .padding()
    }
}

// MARK: - LayoutEditSheet

/// 새 커스텀 레이아웃 추가 시트
private struct LayoutEditSheet: View {

    enum Mode {
        case add
    }

    let mode: Mode
    let onComplete: (LayoutPreset) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = "새 레이아웃"
    @State private var frame: RelativeFrame = RelativeFrame(x: 0, y: 0, width: 0.5, height: 1)

    var body: some View {
        VStack(spacing: 0) {
            Text("새 레이아웃 추가")
                .font(.headline)
                .padding()

            Form {
                TextField("이름", text: $name)

                LabeledContent("X") {
                    sliderRow(value: $frame.x)
                }
                LabeledContent("Y") {
                    sliderRow(value: $frame.y)
                }
                LabeledContent("너비") {
                    sliderRow(value: $frame.width)
                }
                LabeledContent("높이") {
                    sliderRow(value: $frame.height)
                }

                LayoutPreviewView(frame: frame)
                    .frame(height: 100)
            }
            .formStyle(.grouped)

            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Button("추가") {
                    let newLayout = LayoutPreset(name: name, frame: frame, isBuiltIn: false)
                    onComplete(newLayout)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 480)
    }

    private func sliderRow(value: Binding<Double>) -> some View {
        HStack {
            Slider(value: value, in: 0...1, step: 0.01)
                .frame(width: 200)
            Text(String(format: "%.0f%%", value.wrappedValue * 100))
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
