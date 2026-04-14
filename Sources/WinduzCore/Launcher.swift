import Foundation
#if canImport(AppKit)
import AppKit
#endif

public enum Launcher {
    public static let defaultSessionName = "main"

    @discardableResult
    public static func runTmux(_ args: [String]) -> (status: Int32, stdout: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["tmux"] + args
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        do {
            try task.run()
        } catch {
            NSLog("winduz: tmux spawn failed: \(error)")
            return (-1, "")
        }
        task.waitUntilExit()
        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if task.terminationStatus != 0 {
            NSLog("winduz: tmux \(args.joined(separator: " ")) -> \(task.terminationStatus): \(err.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return (task.terminationStatus, out)
    }

    public static func findPane(at path: String) -> String? {
        let (status, out) = runTmux([
            "list-panes", "-a",
            "-F", "#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_path}",
        ])
        guard status == 0 else { return nil }
        for line in out.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { continue }
            if String(parts[1]) == path {
                return String(parts[0])
            }
        }
        return nil
    }

    public static func preferredSession() -> String? {
        let (status, out) = runTmux(["list-sessions", "-F", "#{session_attached}\t#{session_name}"])
        guard status == 0 else { return nil }
        var firstDetached: String?
        for line in out.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let attached = parts[0] != "0"
            let name = String(parts[1])
            if attached { return name }
            if firstDetached == nil { firstDetached = name }
        }
        return firstDetached
    }

    public static func isSessionAttached(_ name: String) -> Bool {
        let (status, out) = runTmux(["list-clients", "-t", name])
        return status == 0 && !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func activateGhostty() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Ghostty"]
        try? task.run()
    }

    public static func spawnGhostty(tmuxArgs: [String]) {
        // Write a temp script so no argument gets misinterpreted by login(1).
        // #!/bin/zsh -l loads the user's PATH (Homebrew etc.) before exec'ing tmux.
        let tmuxLine = (["tmux"] + tmuxArgs).joined(separator: " ")
        let script = "#!/bin/zsh -l\nexec \(tmuxLine)\n"

        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("winduz-\(UUID().uuidString).sh")
        do {
            try script.write(to: tmpURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmpURL.path)
        } catch {
            NSLog("winduz: failed to write launch script: \(error)")
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-na", "Ghostty", "--args", "--command=\(tmpURL.path)"]
        do {
            try task.run()
        } catch {
            NSLog("winduz: failed to launch Ghostty: \(error)")
        }

        // Remove the script after Ghostty has had time to exec it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }

    /// Three-tier launch: focus existing pane, else add window to session, else spawn fresh.
    public static func openPath(_ path: String) {
        Store.shared.touch(path: path)
        if let target = findPane(at: path) {
            NSLog("winduz: openPath pane exists \(target) for \(path)")
            let sessionWindow = target.split(separator: ".").first.map(String.init) ?? target
            runTmux(["select-window", "-t", sessionWindow])
            runTmux(["select-pane", "-t", target])
            activateGhostty()
            return
        }

        if let session = preferredSession() {
            let attached = isSessionAttached(session)
            NSLog("winduz: openPath session=\(session) attached=\(attached) path=\(path)")
            runTmux(["new-window", "-t", "\(session):", "-c", path])
            if attached {
                activateGhostty()
            } else {
                spawnGhostty(tmuxArgs: ["attach", "-t", "\(session):"])
            }
            return
        }

        NSLog("winduz: openPath no session, spawning fresh for \(path)")
        spawnGhostty(tmuxArgs: ["new-session", "-A", "-s", defaultSessionName, "-c", path])
    }
}
