import AppKit

// for the signal handler: prepared in Log.start(), plain C memory (a C handler cannot capture Swift context)
nonisolated(unsafe) private var crashPath: UnsafeMutablePointer<CChar>?
nonisolated(unsafe) private var crashLine: UnsafeMutablePointer<CChar>?

/// Log file `~/Library/Logs/MarkTheRoughcut/MarkTheRoughcut.log`: one line per event, moved to `MarkTheRoughcut.old.log` at 1 MB.
/// Only the real app writes (tests never touch the user's log). A failed write never stops anything.
enum Log {
    static let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/MarkTheRoughcut")
    static let file = folder.appendingPathComponent("MarkTheRoughcut.log")
    private static let enabled = Bundle.main.bundleIdentifier == "io.github.moritz-poth.marktheroughcut"
    private static let queue = DispatchQueue(label: "MarkTheRoughcut.log")
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    /// Waits until every line is written (before the app quits).
    static func flush() { queue.sync {} }

    static func write(_ message: String) {
        guard enabled else { return }
        let now = Date()
        queue.async {
            // DateFormatter only on this queue: it is not thread-safe
            let line = "\(stamp.string(from: now)) \(message.replacingOccurrences(of: "\n", with: " | "))\n"
            let fm = FileManager.default
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            if let size = try? fm.attributesOfItem(atPath: file.path)[.size] as? Int, size > 1_000_000 {
                let old = folder.appendingPathComponent("MarkTheRoughcut.old.log")
                try? fm.removeItem(at: old)
                try? fm.moveItem(at: file, to: old)
            }
            let fd = open(file.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
            guard fd >= 0 else { return }
            let bytes = Array(line.utf8)
            _ = bytes.withUnsafeBytes { Foundation.write(fd, $0.baseAddress, $0.count) }
            close(fd)
        }
    }

    /// Start line plus a note for uncaught Objective-C exceptions and fatal signals (crashes).
    @MainActor static func start() {
        #if arch(arm64)
        let arch = "arm64"
        #else
        let arch = "x86_64"
        #endif
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        write("start MarkTheRoughcut \(AppSettings.version) (\(arch), macOS \(os.replacingOccurrences(of: "Version ", with: "")))")
        NSSetUncaughtExceptionHandler { e in
            Log.write("crash: \(e.name.rawValue): \(e.reason ?? "")")
            Log.flush()
        }
        crashPath = strdup(file.path)
        crashLine = strdup("crash: fatal signal (see the macOS crash report)\n")
        for sig in [SIGSEGV, SIGBUS, SIGILL, SIGABRT, SIGFPE, SIGTRAP] {
            signal(sig) { s in
                // async-signal-safe: path and text prepared before, plain open/write, then the default crash handling
                if let path = crashPath, let crashLine {
                    let fd = open(path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
                    if fd >= 0 { _ = Foundation.write(fd, crashLine, strlen(crashLine)); close(fd) }
                }
                signal(s, SIG_DFL)
                raise(s)
            }
        }
    }

    /// A path in a log line, marked so reports hash all of it (`anonymize`), whatever characters the names contain.
    static func path(_ url: URL) -> String { "‹\(url.path)›" }

    static func reveal() {
        if !FileManager.default.fileExists(atPath: file.path) { write("log opened"); flush() }
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }
}
