import AppKit
import Carbon.HIToolbox

// Claude Code 用グローバルホットキー常駐プログラム。
// Ctrl+Cmd+J で jump-to-notified.sh（最後に通知が来た WezTerm pane へジャンプ）を実行する。
// RegisterEventHotKey はアクセシビリティ権限不要。LaunchAgent として常駐させる。
// キーを変えたいときはこのファイルの kVK_ANSI_J と修飾キーを変えて再コンパイル:
//   xcrun swiftc -O -o ~/.claude/hooks/bin/claude-hotkey ~/.claude/hooks/claude-hotkey.swift

let script = FileManager.default.homeDirectoryForCurrentUser.path + "/.claude/hooks/jump-to-notified.sh"

var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
    let p = Process()
    p.executableURL = URL(fileURLWithPath: script)
    try? p.run()
    return noErr
}, 1, &eventType, nil, nil)

var hotKeyRef: EventHotKeyRef?
let hotKeyID = EventHotKeyID(signature: OSType(0x434C_4448), id: 1) // "CLDH"
let status = RegisterEventHotKey(UInt32(kVK_ANSI_J), UInt32(cmdKey | controlKey),
                                 hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
guard status == noErr else {
    FileHandle.standardError.write("RegisterEventHotKey failed: \(status)\n".data(using: .utf8)!)
    exit(1)
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
app.run()
