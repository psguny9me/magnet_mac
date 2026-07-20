import AppKit

// MARK: - ToastWindow

/// 화면 하단 중앙에 잠시 표시되는 알림 토스트 (메인 스레드 전용)
@MainActor
final class ToastWindow {

    // MARK: - Singleton

    @MainActor static let shared = ToastWindow()

    // MARK: - Private Properties

    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    // MARK: - Public API

    /// 메시지를 표시하고 duration 초 후 자동으로 사라짐
    func show(message: String, duration: TimeInterval = 1.8) {
        hide()

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.sizeToFit()

        let horizontalPadding: CGFloat = 18
        let verticalPadding: CGFloat = 10
        let size = NSSize(
            width: label.frame.width + horizontalPadding * 2,
            height: label.frame.height + verticalPadding * 2
        )

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
        container.layer?.cornerRadius = size.height / 2
        label.setFrameOrigin(NSPoint(x: horizontalPadding, y: verticalPadding))
        container.addSubview(label)

        let newPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.level = .statusBar
        newPanel.ignoresMouseEvents = true
        newPanel.isReleasedWhenClosed = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .transient]
        newPanel.contentView = container

        // 마우스가 있는 화면 하단 중앙에 배치
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let screen {
            let visibleFrame = screen.visibleFrame
            newPanel.setFrameOrigin(NSPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.minY + 80
            ))
        }
        newPanel.orderFrontRegardless()
        panel = newPanel

        let workItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    /// 토스트 즉시 제거
    func hide() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        panel?.close()
        panel = nil
    }
}
