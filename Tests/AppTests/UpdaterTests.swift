import CryptoKit
import Foundation
import Testing
@testable import MarkTheRoughcut

struct UpdaterTests {
    @Test func versionOrder() {
        let v = { AppVersion($0)! }
        #expect(v("v1.0.0-beta.7") < v("v1.0.0-beta.10"))
        #expect(v("1.0.0-beta.7") < v("1.0.0"))
        #expect(v("1.0.0") < v("1.0.1-beta.1"))
        #expect(v("1.0") == v("1.0.0"))
        #expect(!(v("1.0.0-beta.7") < v("v1.0.0-beta.7")))
        #expect(AppVersion("dev") == nil)
        #expect(AppVersion("1.0.0-rc") == nil)
    }

    @Test func newestReleaseSkipsDraftsAndReleasesWithoutZip() {
        let json = """
        [{"tag_name":"v1.0.0-beta.9","html_url":"https://x/9","draft":true,"assets":[{"name":"MarkTheRoughcut-1.0.0-beta.9.zip","browser_download_url":"https://x/9.zip"}]},
         {"tag_name":"v1.0.0-beta.8","html_url":"https://x/8","draft":false,"assets":[]},
         {"tag_name":"v1.0.0-beta.10","html_url":"https://x/10","draft":false,"assets":[{"name":"MarkTheRoughcut-1.0.0-beta.10.zip","browser_download_url":"https://x/10.zip"}]},
         {"tag_name":"v1.0.0-beta.7","html_url":"https://x/7","draft":false,"assets":[{"name":"MarkTheRoughcut-1.0.0-beta.7.zip","browser_download_url":"https://x/7.zip"}]}]
        """
        // nothing is offered without a signature
        #expect(newestRelease(fromJSON: Data(json.utf8)) == nil)
        let r = newestRelease(fromJSON: Data(json.utf8), requireSignature: false)
        #expect(r?.tag == "v1.0.0-beta.10")
        #expect(r?.zip.absoluteString == "https://x/10.zip")
        let signed = json.replacingOccurrences(of: #"{"name":"MarkTheRoughcut-1.0.0-beta.7.zip","browser_download_url":"https://x/7.zip"}"#,
            with: #"{"name":"MarkTheRoughcut-1.0.0-beta.7.zip","browser_download_url":"https://x/7.zip"},{"name":"MarkTheRoughcut-1.0.0-beta.7.zip.sig","browser_download_url":"https://x/7.sig"}"#)
        #expect(newestRelease(fromJSON: Data(signed.utf8))?.signature?.absoluteString == "https://x/7.sig")
        // key lost: marker ".manual" → notice to install by hand, never automatically
        let manual = json.replacingOccurrences(of: #"{"name":"MarkTheRoughcut-1.0.0-beta.10.zip","browser_download_url":"https://x/10.zip"}"#,
            with: #"{"name":"MarkTheRoughcut-1.0.0-beta.10.zip","browser_download_url":"https://x/10.zip"},{"name":"MarkTheRoughcut-1.0.0-beta.10.manual","browser_download_url":"https://x/10.manual"}"#)
        let m = newestRelease(fromJSON: Data(manual.utf8))
        #expect(m?.tag == "v1.0.0-beta.10" && m?.manual == true && m?.signature == nil)
        // only links to this project are opened
        #expect(m?.safePage == Release.releasesPage)
        let own = Release(tag: "v1", page: URL(string: "https://github.com/moritz-poth/marktheroughcut/releases/tag/v1")!, zip: Release.releasesPage, signature: nil, manual: true)
        #expect(own.safePage == own.page)
        let evil = Release(tag: "v1", page: URL(string: "https://github.com/moritz-poth/marktheroughcut/releases.evil.com/x")!, zip: Release.releasesPage, signature: nil, manual: true)
        #expect(evil.safePage == Release.releasesPage)
        #expect(newestRelease(fromJSON: Data("{\"message\":\"rate limit\"}".utf8)) == nil)
    }

    /// Uses the zip from scripts/build-app.sh, if there is one.
    @Test func unpackAcceptsOnlyTheExpectedIntactApp() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let dist = root.appendingPathComponent("dist")
        // the zip of the version build-app.sh builds now – not an old one
        let script = try String(contentsOf: root.appendingPathComponent("scripts/build-app.sh"), encoding: .utf8)
        guard let release = script.split(separator: "\n").first(where: { $0.hasPrefix("RELEASE=") })?
                .dropFirst("RELEASE=".count).split(separator: " ").first.map(String.init) else { Issue.record("no RELEASE in build-app.sh"); return }
        let zipName = "MarkTheRoughcut-\(release).zip"
        guard FileManager.default.fileExists(atPath: dist.appendingPathComponent(zipName).path) else {
            // before a release (MARKTHEROUGHCUT_RELEASE=1) the build must exist, or the test would pass silently
            if ProcessInfo.processInfo.environment["MARKTHEROUGHCUT_RELEASE"] == "1" { Issue.record("\(zipName) missing – run scripts/build-app.sh first") }
            return
        }
        let zip = dist.appendingPathComponent(zipName)
        let tag = "v" + zipName.dropFirst("MarkTheRoughcut-".count).dropLast(".zip".count)
        let id = "io.github.moritz-poth.marktheroughcut"
        // own test key instead of the real one (that lives only in the release Mac's Keychain)
        let key = Curve25519.Signing.PrivateKey()
        let pub = key.publicKey.rawRepresentation.base64EncodedString()
        func sign(_ url: URL) throws -> Data { Data(try key.signature(for: Data(contentsOf: url)).base64EncodedString().utf8) }
        let sig = try sign(zip)
        func unpack(_ z: URL, _ t: String, _ s: Data?, _ b: String = id, _ k: String = pub) throws -> URL {
            try Updater.unpack(z, expecting: t, signature: s, publicKey: k, bundleID: b)
        }
        let app = try unpack(zip, tag, sig)
        #expect(FileManager.default.fileExists(atPath: app.appendingPathComponent("Contents/MacOS/MarkTheRoughcut").path))
        #expect(throws: Updater.UpdateError.self) { try unpack(zip, "v9.9.9", sig) }
        #expect(throws: Updater.UpdateError.self) { try unpack(zip, tag, sig, "other.app") }
        // unsigned, signed by someone else, or signature of another file: refused
        #expect(throws: Updater.UpdateError.self) { try unpack(zip, tag, nil) }
        #expect(throws: Updater.UpdateError.self) { try unpack(zip, tag, sig, id, Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()) }
        // tampered: a changed file breaks the code signature (even if the zip itself were signed)
        let bad = try unpack(zip, tag, sig)
        try Data("x".utf8).write(to: bad.appendingPathComponent("Contents/Resources/LICENSE.txt"))
        let tampered = bad.deletingLastPathComponent().appendingPathComponent("t.zip")
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-c", "-k", "--keepParent", bad.path, tampered.path]; try p.run(); p.waitUntilExit()
        #expect(throws: Updater.UpdateError.self) { try unpack(tampered, tag, try sign(tampered)) }
        #expect(throws: Updater.UpdateError.self) { try unpack(tampered, tag, sig) }
    }

    /// The zip from build-app.sh is signed with the key the app trusts (if build-app.sh could sign it).
    @Test func builtZipMatchesTheAppsKey() throws {
        let dist = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("dist")
        guard let sigName = try? FileManager.default.contentsOfDirectory(atPath: dist.path).first(where: { $0.hasSuffix(".zip.sig") }) else { return }
        let zip = try Data(contentsOf: dist.appendingPathComponent(String(sigName.dropLast(4))))
        let sig = try Data(contentsOf: dist.appendingPathComponent(sigName))
        #expect(Updater.signatureValid(zip, sig))
        #expect(!Updater.signatureValid(zip + Data([0]), sig))
    }

    @Test func prereleasesOnlyWhenAsked() {
        let json = """
        [{"tag_name":"v1.0.0-beta.2","html_url":"https://x/2","draft":false,"prerelease":true,"assets":[{"name":"MarkTheRoughcut-1.0.0-beta.2.zip","browser_download_url":"https://x/2.zip"},{"name":"MarkTheRoughcut-1.0.0-beta.2.zip.sig","browser_download_url":"https://x/2.sig"}]},
         {"tag_name":"v1.0.0-beta.1","html_url":"https://x/1","draft":false,"prerelease":false,"assets":[{"name":"MarkTheRoughcut-1.0.0-beta.1.zip","browser_download_url":"https://x/1.zip"},{"name":"MarkTheRoughcut-1.0.0-beta.1.zip.sig","browser_download_url":"https://x/1.sig"}]}]
        """
        #expect(newestRelease(fromJSON: Data(json.utf8))?.tag == "v1.0.0-beta.1")
        #expect(newestRelease(fromJSON: Data(json.utf8), includePrereleases: true)?.tag == "v1.0.0-beta.2")
    }

    @Test func liveGitHubHasAParsableRelease() async throws {
        guard ProcessInfo.processInfo.environment["MARKTHEROUGHCUT_IT"] == "1" else { return }
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://api.github.com/repos/moritz-poth/marktheroughcut/releases?per_page=20")!)
        let r = try #require(newestRelease(fromJSON: data, includePrereleases: true))
        #expect(AppVersion(r.tag)! >= AppVersion("v1.0.0-beta.1")!)
    }
}
