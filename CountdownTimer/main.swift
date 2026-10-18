import Cocoa

// 计时器状态
enum TimerStatus {
    case notStarted
    case paused
    case running
}

// 自定义内容视图：绘制圆角半透明背景 + 倒计时数字 + 状态文字，并区分「单击」与「拖动」
final class DragView: NSView {
    var timeText: String = "30:00" {
        didSet { needsDisplay = true }
    }
    var textIsNegative: Bool = false {
        didSet { needsDisplay = true }
    }
    var status: TimerStatus = .notStarted {
        didSet { needsDisplay = true }
    }
    var onToggle: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?

    private let cornerRadius: CGFloat = 14
    private let background = NSColor(srgbRed: 0.678, green: 0.847, blue: 0.902, alpha: 0.8) // 浅蓝 #ADD8E6，恒定不变
    private let positiveColor = NSColor.white
    private let negativeColor = NSColor(srgbRed: 1.0, green: 0.25, blue: 0.25, alpha: 1.0) // 红色
    private let fontSize: CGFloat = 52

    private var downScreenPoint: NSPoint = .zero
    private var downWindowOrigin: NSPoint = .zero
    private var dragged = false

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)

        // 背景：恒定浅蓝
        background.setFill()
        NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 1

        // 数字：白色恒定，负数红色
        let textColor = textIsNegative ? negativeColor : positiveColor
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: textColor,
            .shadow: shadow
        ]
        let size = timeText.size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        timeText.draw(at: point, withAttributes: attrs)

        drawStatusLabel()
    }

    // 右下角状态文字：未开始 / 暂停（运行中不显示）
    private func drawStatusLabel() {
        guard status != .running else { return }
        let text = (status == .paused) ? "暂停" : "未开始"
        let color: NSColor = (status == .paused)
            ? NSColor(srgbRed: 0.90, green: 0.45, blue: 0.05, alpha: 1.0)   // 暂停：橙色
            : NSColor(srgbRed: 0.36, green: 0.42, blue: 0.48, alpha: 1.0)   // 未开始：深灰蓝
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: color
        ]
        let size = text.size(withAttributes: attrs)
        let pad: CGFloat = 12
        text.draw(at: NSPoint(x: bounds.width - pad - size.width, y: pad), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        downScreenPoint = NSEvent.mouseLocation
        downWindowOrigin = window?.frame.origin ?? .zero
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - downScreenPoint.x
        let dy = now.y - downScreenPoint.y
        if abs(dx) > 2 || abs(dy) > 2 { dragged = true }
        if dragged {
            window.setFrameOrigin(NSPoint(x: downWindowOrigin.x + dx, y: downWindowOrigin.y + dy))
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !dragged { onToggle?() }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var view: DragView!
    private var timer: Timer?

    private var remaining: TimeInterval = 30 * 60
    private var running = false
    private var hasStarted = false
    private var lastUpdate: Date?
    private var didBeep = false
    private weak var durationMinField: NSTextField?
    private weak var durationSecField: NSTextField?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        updateDisplay()
    }

    private func buildWindow() {
        let w: CGFloat = 280, h: CGFloat = 104
        let rect = NSRect(x: 0, y: 0, width: w, height: h)
        window = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .statusBar                       // 置顶，高于普通应用与 PPT/Keynote 全屏放映
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false

        view = DragView(frame: rect)
        view.onToggle = { [weak self] in self?.toggle() }
        view.onRightClick = { [weak self] event in self?.showMenu(event) }
        window.contentView = view

        positionTopRight()
        window.orderFrontRegardless()
    }

    private func positionTopRight() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 24
        let x = visible.maxX - window.frame.width - margin
        let y = visible.maxY - window.frame.height - margin
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: 显示格式：MM:SS，超过 60 分钟变 H:MM:SS，负数带负号
    private func timeString(for seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let negative = total < 0
        let v = abs(total)
        let h = v / 3600
        let m = (v % 3600) / 60
        let s = v % 60
        let sign = negative ? "-" : ""
        if h > 0 {
            return String(format: "%@%d:%02d:%02d", sign, h, m, s)
        } else {
            return String(format: "%@%02d:%02d", sign, m, s)
        }
    }

    private func updateDisplay() {
        view.timeText = timeString(for: remaining)
        view.textIsNegative = Int(remaining.rounded(.down)) < 0
        if running {
            view.status = .running
        } else if hasStarted {
            view.status = .paused
        } else {
            view.status = .notStarted
        }
    }

    // MARK: 计时
    private func toggle() {
        running ? pause() : start()
    }

    private func start() {
        guard !running else { return }
        running = true
        hasStarted = true
        lastUpdate = Date()
        let t = Timer(timeInterval: 0.1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common) // 拖动窗口、打开菜单时也持续计时
        timer = t
        updateDisplay()
    }

    private func pause() {
        running = false
        timer?.invalidate()
        timer = nil
        lastUpdate = nil
        updateDisplay()
    }

    @objc private func tick() {
        let now = Date()
        if let last = lastUpdate {
            remaining -= now.timeIntervalSince(last)
        }
        lastUpdate = now
        if remaining <= 0 && !didBeep {
            didBeep = true
            NSSound.beep()
        }
        updateDisplay()
    }

    private func reset(to seconds: TimeInterval) {
        pause()
        hasStarted = false
        remaining = seconds
        didBeep = false
        updateDisplay()
    }

    // MARK: 右键菜单
    private func showMenu(_ event: NSEvent) {
        let menu = NSMenu()
        let setItem = NSMenuItem(title: "设定时长…", action: #selector(showSetDurationDialog), keyEquivalent: "")
        setItem.target = self
        menu.addItem(setItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func presetSelected(_ sender: NSButton) {
        let seconds = sender.tag
        durationMinField?.stringValue = String(seconds / 60)
        durationSecField?.stringValue = "0"
        NSApp.stopModal(withCode: .alertFirstButtonReturn)
    }

    @objc private func showSetDurationDialog() {
        let currentTotal = max(0, Int(remaining.rounded(.down)))
        let curMin = currentTotal / 60
        let curSec = currentTotal % 60

        let alert = NSAlert()
        alert.messageText = "设定倒计时时长"
        alert.informativeText = "点预设直接开始，或输入分钟 / 秒后点「确定」。"
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let minField = NSTextField(frame: NSRect(x: 0, y: 0, width: 64, height: 24))
        minField.stringValue = String(curMin)
        let secField = NSTextField(frame: NSRect(x: 116, y: 0, width: 64, height: 24))
        secField.stringValue = String(curSec)

        let minLabel = NSTextField(labelWithString: "分钟")
        minLabel.frame = NSRect(x: 0, y: 26, width: 64, height: 16)
        let secLabel = NSTextField(labelWithString: "秒")
        secLabel.frame = NSRect(x: 116, y: 26, width: 64, height: 16)

        let customLabel = NSTextField(labelWithString: "自定义时长（分钟 / 秒）：")
        customLabel.frame = NSRect(x: 0, y: 48, width: 260, height: 16)

        let presetLabel = NSTextField(labelWithString: "预设时长：")
        presetLabel.frame = NSRect(x: 6, y: 104, width: 120, height: 18)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 122))
        container.addSubview(minLabel)
        container.addSubview(secLabel)
        container.addSubview(minField)
        container.addSubview(secField)
        container.addSubview(customLabel)
        container.addSubview(presetLabel)
        container.addSubview(presetButton("30 分钟", 30 * 60, x: 6))
        container.addSubview(presetButton("45 分钟", 45 * 60, x: 98))
        container.addSubview(presetButton("60 分钟", 60 * 60, x: 190))

        durationMinField = minField
        durationSecField = secField

        alert.accessoryView = container
        alert.window.initialFirstResponder = minField

        if alert.runModal() == .alertFirstButtonReturn {
            let minutes = max(0, Int(minField.stringValue) ?? 0)
            var sec = Int(secField.stringValue) ?? 0
            sec = min(59, max(0, sec))
            reset(to: TimeInterval(minutes * 60 + sec))
        }
        durationMinField = nil
        durationSecField = nil
    }

    private func presetButton(_ title: String, _ seconds: Int, x: CGFloat) -> NSButton {
        let b = NSButton(title: title, target: self, action: #selector(presetSelected(_:)))
        b.tag = seconds
        b.frame = NSRect(x: x, y: 70, width: 84, height: 28)
        b.bezelStyle = .rounded
        b.font = NSFont.systemFont(ofSize: 14)
        return b
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
