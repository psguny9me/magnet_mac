import AppKit

// MARK: - SnapPreviewWindow

/// 드래그 트리거 시 스냅 미리보기 반투명 오버레이 창 (메인 스레드 전용)
@MainActor
final class SnapPreviewWindow {

    // MARK: - Singleton

    @MainActor static let shared = SnapPreviewWindow()

    // MARK: - Constants

    private enum Constant {
        static let cornerRadius: CGFloat = 8
        static let borderWidth: CGFloat = 1
        static let fadeInDuration: TimeInterval = 0.1
        static let fadeOutDuration: TimeInterval = 0.15
        static let fillAlpha: CGFloat = 0.25
        static let borderAlpha: CGFloat = 0.6
    }

    // MARK: - Private Properties

    private var overlayWindow: NSWindow?
    private var isVisible: Bool = false

    /// show/hide 세대 번호. 페이드아웃 완료 핸들러가 그 사이 다시 표시된 창을 내리지 않도록 한다
    private var generation: Int = 0

    private init() {}

    // MARK: - Public API

    /// 지정된 프레임 위치에 미리보기 오버레이를 표시 (fade-in 애니메이션)
    func show(frame: CGRect) {
        if overlayWindow == nil {
            createOverlayWindow()
        }
        guard let window = overlayWindow else { return }

        generation += 1
        window.setFrame(frame, display: false)

        if !isVisible {
            // 처음 나타날 때만 0에서 페이드인. 이미 보이는 창은 위치만 바꿔 깜빡임을 막는다
            window.alphaValue = 0
            window.orderFront(nil)
            isVisible = true
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constant.fadeInDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 1
        }
    }

    /// 미리보기 오버레이를 숨김 (fade-out 애니메이션)
    func hide() {
        guard isVisible, let window = overlayWindow else { return }
        generation += 1
        let hideGeneration = generation

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Constant.fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
        }, completionHandler: {
            // 완료 핸들러는 메인 스레드에서 불리지만 @Sendable이라 격리를 명시한다
            MainActor.assumeIsolated {
                // 페이드아웃 중에 show()가 다시 불렸으면 창을 내리지 않는다
                guard self.generation == hideGeneration else { return }
                window.orderOut(nil)
                self.isVisible = false
            }
        })
    }

    // MARK: - Window Creation

    private func createOverlayWindow() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.hasShadow = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let contentView = SnapPreviewContentView()
        window.contentView = contentView

        overlayWindow = window
    }
}

// MARK: - SnapPreviewContentView

/// 스냅 미리보기 오버레이의 내용 뷰 (반투명 파란색 배경 + 테두리)
private final class SnapPreviewContentView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let inset: CGFloat = 1
        let insetBounds = bounds.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(roundedRect: insetBounds, xRadius: 8, yRadius: 8)

        // 반투명 파란색 배경
        NSColor.systemBlue.withAlphaComponent(0.25).setFill()
        path.fill()

        // 파란색 테두리
        NSColor.systemBlue.withAlphaComponent(0.6).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    override var isFlipped: Bool { false }
}
