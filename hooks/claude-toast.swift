import AppKit

// Claude Code 用のカスタムトースト通知。
// 通知センターの代わりに自前のフローティングウィンドウを「ふわっと」表示する。
// - クリック: WezTerm の該当 pane にフォーカスして消える
// - 対象 pane にフォーカスが戻る: 自動でフェードアウト
// 使い方: claude-toast -title <タイトル> -message <本文> [-pane <pane_id>]

let args = CommandLine.arguments
func argValue(_ name: String) -> String? {
    if let i = args.firstIndex(of: name), i + 1 < args.count { return args[i + 1] }
    return nil
}
let toastTitle = argValue("-title") ?? "Claude Code"
let toastMessage = argValue("-message") ?? ""
let targetPane = argValue("-pane")

let home = FileManager.default.homeDirectoryForCurrentUser.path
let weztermBin = "/opt/homebrew/bin/wezterm"
let iconPath = home + "/.claude/hooks/Claude Code.app/Contents/Resources/Terminal.icns"

func shell(_ cmd: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/bash")
    p.arguments = ["-c", cmd]
    try? p.run()
}

func focusedPaneId() -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: weztermBin)
    p.arguments = ["cli", "list-clients", "--format", "json"]
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
    for c in arr { if let f = c["focused_pane_id"] { return "\(f)" } }
    return nil
}

// 複数トーストが重ならないよう、既存インスタンス数だけ縦にずらす
func instanceOffset() -> Int {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    p.arguments = ["-x", "claude-toast"]
    let pipe = Pipe()
    p.standardOutput = pipe
    try? p.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    let mine = ProcessInfo.processInfo.processIdentifier
    let others = String(data: data, encoding: .utf8)?
        .split(separator: "\n").compactMap { Int32($0) }.filter { $0 != mine } ?? []
    return others.count
}

final class ToastView: NSVisualEffectView {
    var onClick: (() -> Void)?
    override func mouseDown(with event: NSEvent) { onClick?() }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSPanel!
    var timer: Timer?
    var dismissing = false

    func applicationDidFinishLaunching(_ note: Notification) {
        let width: CGFloat = 344
        let pad: CGFloat = 14
        let iconSize: CGFloat = 38
        let textX = pad + iconSize + 12
        let textWidth = width - textX - pad

        let msgFont = NSFont.systemFont(ofSize: 12.5)
        let msgBounds = (toastMessage as NSString).boundingRect(
            with: NSSize(width: textWidth, height: 60),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: msgFont])
        let msgHeight = min(ceil(msgBounds.height), 48)
        let height = max(iconSize + pad * 2, pad * 2 + 19 + msgHeight)

        let effect = ToastView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 15
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 0.5
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        effect.onClick = { [weak self] in
            if let pane = targetPane {
                shell("/usr/bin/open -a WezTerm && \(weztermBin) cli activate-pane --pane-id \(pane)")
            } else {
                shell("/usr/bin/open -a WezTerm")
            }
            self?.dismiss()
        }

        if let icon = NSImage(contentsOfFile: iconPath) {
            let iv = NSImageView(frame: NSRect(x: pad, y: (height - iconSize) / 2, width: iconSize, height: iconSize))
            iv.image = icon
            iv.imageScaling = .scaleProportionallyUpOrDown
            effect.addSubview(iv)
        }

        let titleField = NSTextField(labelWithString: toastTitle)
        titleField.font = .boldSystemFont(ofSize: 13)
        titleField.frame = NSRect(x: textX, y: height - pad - 17, width: textWidth, height: 17)
        titleField.lineBreakMode = .byTruncatingTail
        effect.addSubview(titleField)

        let msgField = NSTextField(wrappingLabelWithString: toastMessage)
        msgField.font = msgFont
        msgField.textColor = .secondaryLabelColor
        msgField.frame = NSRect(x: textX, y: height - pad - 19 - msgHeight, width: textWidth, height: msgHeight)
        effect.addSubview(msgField)

        guard let screen = NSScreen.main else { NSApp.terminate(nil); return }
        let vf = screen.visibleFrame
        let stack = CGFloat(instanceOffset()) * (height + 10)
        let target = NSRect(x: vf.maxX - width - 16, y: vf.maxY - height - 16 - stack, width: width, height: height)

        window = NSPanel(contentRect: target, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = effect

        // ふわっと出現: 少し上からフェードインしながら降りてくる
        window.alphaValue = 0
        window.setFrame(target.offsetBy(dx: 0, dy: 14), display: false)
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.55
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
            window.animator().setFrame(target, display: true)
        }

        // 対象 pane にフォーカスが戻ったら自動で消える
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let front = NSWorkspace.shared.frontmostApplication else { return }
            let isWez = front.bundleIdentifier == "com.github.wez.wezterm"
                || (front.localizedName ?? "").contains("WezTerm")
            guard isWez else { return }
            if let pane = targetPane {
                if focusedPaneId() == pane { self?.dismiss() }
            } else {
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        guard !dismissing else { return }
        dismissing = true
        timer?.invalidate()
        let sunk = window.frame.offsetBy(dx: 0, dy: 10)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
            window.animator().setFrame(sunk, display: true)
        }, completionHandler: { NSApp.terminate(nil) })
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
