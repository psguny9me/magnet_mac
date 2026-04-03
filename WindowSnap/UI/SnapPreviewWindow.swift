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

    private init() {}

    // MARK: - Public API

    /// 지정된 프레임 위치에 미리보기 오버레이를 표시 (fade-in 애니메이션)
    func show(frame: CGRect) {
        if overlayWindow == nil {
            createOverlayWindow()
        }
        guard let window = overlayWindow else { return }

        window.setFrame(frame, display: false)
        window.alphaValue = 0

        if !isVisible {
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

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Constant.fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            self.isVisible = false
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
