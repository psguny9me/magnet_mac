import SwiftUI

// MARK: - OnboardingStep

/// 온보딩 단계 정의
enum OnboardingStep: Int, CaseIterable {
    case welcome        = 0
    case accessibility  = 1
    case shortcuts      = 2
}

// MARK: - OnboardingView

/// 앱 최초 실행 시 표시되는 3단계 온보딩 뷰
struct OnboardingView: View {

    /// "시작하기"를 눌렀을 때 호출. 창 닫기와 서비스 시작은 AppDelegate가 담당한다
    let onComplete: () -> Void

    @State private var currentStep: OnboardingStep = .welcome
    @State private var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    var body: some View {
        VStack(spacing: 0) {
            // 진행 표시기
            stepIndicator
                .padding(.top, 24)

            // 단계별 내용
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 하단 버튼
            navigationButtons
                .padding(.bottom, 24)
        }
        .frame(width: 540, height: 420)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step == currentStep ? Color.accentColor : Color(.separatorColor))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: currentStep)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            WelcomeStepView()
        case .accessibility:
            AccessibilityStepView(
                isGranted: $isAccessibilityGranted,
                onCheckPermission: checkAccessibility
            )
        case .shortcuts:
            ShortcutsGuideStepView()
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            if currentStep != .welcome {
                Button("이전") {
                    withAnimation { moveToPreviousStep() }
                }
                .buttonStyle(.borderless)
            }

            Spacer()

            if currentStep == .shortcuts {
                Button("시작하기") {
                    completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button(nextButtonTitle) {
                    withAnimation { moveToNextStep() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(currentStep == .accessibility && !isAccessibilityGranted)
            }
        }
        .padding(.horizontal, 32)
    }

    private var nextButtonTitle: String {
        currentStep == .accessibility ? "권한 확인" : "다음"
    }

    // MARK: - Navigation Actions

    private func moveToNextStep() {
        guard let nextRaw = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextRaw
    }

    private func moveToPreviousStep() {
        guard let prevRaw = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prevRaw
    }

    private func checkAccessibility() {
        isAccessibilityGranted = AXIsProcessTrusted()
        if isAccessibilityGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { currentStep = .shortcuts }
            }
        }
    }

    private func completeOnboarding() {
        AppSettings.shared.hasCompletedOnboarding = true
        onComplete()
    }
}

// MARK: - WelcomeStepView

/// 온보딩 1단계: 앱 소개
private struct WelcomeStepView: View {

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("WindowSnap에 오신 것을 환영합니다")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("키보드 단축키와 드래그 트리거로\n창을 빠르게 원하는 위치에 배치하세요.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            // 주요 기능 요약
            HStack(spacing: 32) {
                featureItem(icon: "keyboard", title: "단축키", desc: "⌃⌥ 조합으로\n즉시 배치")
                featureItem(icon: "cursorarrow.motionlines", title: "드래그", desc: "가장자리로 드래그\n하여 스냅")
                featureItem(icon: "rectangle.3.group", title: "16가지 레이아웃", desc: "절반, 1/4, 1/3\n등 다양한 배치")
            }
        }
        .padding(40)
    }

    private func featureItem(icon: String, title: String, desc: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 120)
    }
}

// MARK: - AccessibilityStepView

/// 온보딩 2단계: Accessibility 권한 요청
private struct AccessibilityStepView: View {

    @Binding var isGranted: Bool
    let onCheckPermission: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: isGranted ? "checkmark.shield.fill" : "shield.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(isGranted ? .green : .orange)
                .animation(.easeInOut, value: isGranted)

            VStack(spacing: 8) {
                Text("접근성 권한이 필요합니다")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("WindowSnap이 창을 이동하고 크기를 조절하려면\n손쉬운 사용(Accessibility) 권한이 필요합니다.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            if isGranted {
                Label("접근성 권한이 허용되었습니다.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                VStack(spacing: 12) {
                    Button("시스템 설정 열기") {
                        openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)

                    Button("권한 확인") {
                        onCheckPermission()
                    }
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }
        }
        .padding(40)
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let url {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - ShortcutsGuideStepView

/// 온보딩 3단계: 기본 단축키 안내
private struct ShortcutsGuideStepView: View {

    private let shortcuts: [(String, String)] = [
        ("⌃⌥←", "좌측 절반"),
        ("⌃⌥→", "우측 절반"),
        ("⌃⌥↑", "상단 절반"),
        ("⌃⌥↓", "하단 절반"),
        ("⌃⌥U", "좌상단 1/4"),
        ("⌃⌥I", "우상단 1/4"),
        ("⌃⌥↩", "전체화면"),
        ("⌃⌥C", "화면 중앙"),
        ("⌃⌥⌫", "원래 크기 복원"),
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("기본 단축키 안내")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(shortcuts, id: \.0) { shortcut, name in
                    shortcutCell(keys: shortcut, name: name)
                }
            }
            .padding(.horizontal)

            Text("환경설정 > 단축키에서 원하는 단축키로 변경할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }

    private func shortcutCell(keys: String, name: String) -> some View {
        VStack(spacing: 4) {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
