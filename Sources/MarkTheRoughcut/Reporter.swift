import AppKit
import Foundation

/// Sends self-test reports and problem reports to the receiver (Cloudflare Worker in Mountpoint's `worker/`, shared by
/// Moe's apps), which files them as issues in the private repo moritz-poth/marktheroughcut-reports (`product`).
/// No key in the app: the worker validates and rate-limits. If sending fails, the report is saved in Downloads.
enum Reporter {
    static let endpoint = URL(string: "https://mountpoint-reports.moritz-poth.workers.dev/report")

    enum Outcome: Equatable { case sent(String), saved(String), failed(String) }

    static func encode(_ report: SelfTestReport) -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? e.encode(report)) ?? Data()
    }

    /// Send; on failure save as a file and say where.
    static func send(_ report: SelfTestReport) async -> Outcome {
        let body = encode(report)
        if let endpoint {
            var req = URLRequest(url: endpoint, timeoutInterval: 30)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("MarkTheRoughcut/\(report.app)", forHTTPHeaderField: "User-Agent")
            req.httpBody = body
            if let (data, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200 {
                let id = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["id"] as? String ?? ""
                Log.write("report sent: \(report.kind) \(id)")
                return .sent(id)
            }
        }
        switch save(report) {
        case .saved(let path): Log.write("report saved (sending failed): \(Log.path(URL(fileURLWithPath: path)))"); return .failed(path)
        case let other: return other
        }
    }

    /// Save as a file in Downloads (and show it in the Finder).
    @discardableResult
    static func save(_ report: SelfTestReport, reveal: Bool = false) -> Outcome {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        let dir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("MarkTheRoughcut-\(report.kind)-\(f.string(from: Date())).json")
        do {
            try encode(report).write(to: url, options: .atomic)
            if reveal { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            return .saved(url.path)
        } catch {
            return .failed("")
        }
    }

    /// Problem report: description, optional contact, optional system info and log (anonymized).
    @MainActor static func problem(text: String, contact: String, attach: Bool) -> SelfTestReport {
        SelfTestReport(kind: "problem", app: Updater.current, build: SelfTest.build, date: ISO8601DateFormatter().string(from: Date()),
                       system: attach ? SelfTest.systemInfo() : [:], results: [], durationSeconds: 0,
                       log: attach ? SelfTest.logTail() : [], note: text, contact: contact.isEmpty ? nil : contact)
    }
}
