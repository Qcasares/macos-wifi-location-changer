import Foundation
import LocationChangerCore

// Hand-rolled test runner.
//
// swift-testing's `_Testing_Foundation` module is missing from the
// Command Line Tools toolchain, which makes SPM's `swift test` unusable
// without full Xcode. This executable covers the same ground and can be
// run via `swift run LocationChangerTests`.

struct TestFailure: Error {
    let file: StaticString
    let line: UInt
    let message: String
}

final class TestCase {
    let name: String
    var failures: [TestFailure] = []

    init(_ name: String) { self.name = name }

    func expect<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ label: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        if actual != expected {
            failures.append(TestFailure(
                file: file,
                line: line,
                message: "\(label.isEmpty ? "" : "[\(label)] ")expected \(expected), got \(actual)"
            ))
        }
    }

    func expectTrue(
        _ cond: Bool,
        _ label: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        if !cond {
            failures.append(TestFailure(
                file: file,
                line: line,
                message: "\(label.isEmpty ? "" : "[\(label)] ")expected true"
            ))
        }
    }

    func expectThrows(
        _ label: String = "",
        file: StaticString = #file,
        line: UInt = #line,
        _ body: () throws -> Void
    ) {
        do {
            try body()
            failures.append(TestFailure(
                file: file,
                line: line,
                message: "\(label.isEmpty ? "" : "[\(label)] ")expected throw, nothing thrown"
            ))
        } catch {
            // ok
        }
    }
}

final class Runner {
    var cases: [TestCase] = []
    var passed = 0
    var failed = 0

    func run(_ name: String, _ body: (TestCase) throws -> Void) {
        let tc = TestCase(name)
        cases.append(tc)
        do {
            try body(tc)
        } catch {
            tc.failures.append(TestFailure(file: #file, line: #line, message: "unexpected throw: \(error)"))
        }
        if tc.failures.isEmpty {
            passed += 1
            print("  PASS  \(name)")
        } else {
            failed += 1
            print("  FAIL  \(name)")
            for f in tc.failures {
                print("        \(f.file):\(f.line): \(f.message)")
            }
        }
    }

    func summary() -> Int32 {
        print("")
        print("\(passed) passed, \(failed) failed")
        return failed == 0 ? 0 : 1
    }
}

// MARK: - RuleEngine

func ruleEngineTests(_ r: Runner) {
    func cfg(fallback: String = "Automatic", rules: [Rule] = []) -> Config {
        Config(fallback: fallback, notificationsEnabled: true, rules: rules)
    }

    r.run("RuleEngine: fallback when SSID is nil") { t in
        t.expect(RuleEngine.resolve(ssid: nil, in: cfg(rules: [Rule(ssid: "Home", location: "HomeLoc")])), "Automatic")
    }
    r.run("RuleEngine: fallback when SSID is empty") { t in
        t.expect(RuleEngine.resolve(ssid: "", in: cfg(rules: [Rule(ssid: "Home", location: "HomeLoc")])), "Automatic")
    }
    r.run("RuleEngine: exact match") { t in
        let c = cfg(rules: [Rule(ssid: "Home", location: "HomeLoc"), Rule(ssid: "Work", location: "WorkLoc")])
        t.expect(RuleEngine.resolve(ssid: "Home", in: c), "HomeLoc")
        t.expect(RuleEngine.resolve(ssid: "Work", in: c), "WorkLoc")
    }
    r.run("RuleEngine: case-insensitive match") { t in
        let c = cfg(rules: [Rule(ssid: "Home-WiFi", location: "HomeLoc")])
        t.expect(RuleEngine.resolve(ssid: "home-wifi", in: c), "HomeLoc")
        t.expect(RuleEngine.resolve(ssid: "HOME-WIFI", in: c), "HomeLoc")
    }
    r.run("RuleEngine: fallback when no rule matches") { t in
        let c = cfg(fallback: "Auto", rules: [Rule(ssid: "Home", location: "HomeLoc")])
        t.expect(RuleEngine.resolve(ssid: "Cafe", in: c), "Auto")
    }
    r.run("RuleEngine: first match wins") { t in
        let c = cfg(rules: [Rule(ssid: "Net", location: "First"), Rule(ssid: "Net", location: "Second")])
        t.expect(RuleEngine.resolve(ssid: "Net", in: c), "First")
    }
    r.run("RuleEngine: empty rules") { t in
        t.expect(RuleEngine.resolve(ssid: "AnySSID", in: cfg(fallback: "Auto")), "Auto")
    }

    r.run("RuleEngine.validate: clean config") { t in
        let c = cfg(fallback: "Automatic", rules: [
            Rule(ssid: "A", location: "Home"),
            Rule(ssid: "B", location: "Work"),
        ])
        let v = RuleEngine.validate(c, against: ["Automatic", "Home", "Work"])
        t.expectTrue(v.isClean, "isClean")
        t.expectTrue(v.unknownRuleLocations.isEmpty, "no unknown rules")
        t.expectTrue(!v.fallbackIsUnknown, "fallback known")
    }

    r.run("RuleEngine.validate: flags unknown rule location") { t in
        let c = cfg(fallback: "Automatic", rules: [
            Rule(ssid: "A", location: "Home"),
            Rule(ssid: "B", location: "Nonexistent"),
        ])
        let v = RuleEngine.validate(c, against: ["Automatic", "Home"])
        t.expect(v.unknownRuleLocations.count, 1)
        t.expect(v.unknownRuleLocations.first?.ssid ?? "", "B")
        t.expectTrue(!v.fallbackIsUnknown, "fallback still known")
        t.expectTrue(!v.isClean, "not clean")
    }

    r.run("RuleEngine.validate: flags unknown fallback") { t in
        let c = cfg(fallback: "GhostLocation", rules: [])
        let v = RuleEngine.validate(c, against: ["Automatic", "Home"])
        t.expectTrue(v.fallbackIsUnknown, "fallback flagged")
        t.expectTrue(!v.isClean, "not clean")
    }

    r.run("RuleEngine.explain: matched returns the rule") { t in
        let rule = Rule(ssid: "Home", location: "HomeLoc")
        let c = cfg(rules: [rule, Rule(ssid: "Work", location: "WorkLoc")])
        let res = RuleEngine.explain(ssid: "Home", in: c)
        if case .matched(let m) = res {
            t.expect(m.ssid, "Home")
            t.expect(m.location, "HomeLoc")
            t.expect(m.id, rule.id)
        } else {
            t.expectTrue(false, "expected .matched, got \(res)")
        }
    }

    r.run("RuleEngine.explain: nil/empty ssid → .fallback(.noSSID)") { t in
        let c = cfg(rules: [Rule(ssid: "Home", location: "HomeLoc")])
        t.expectTrue(RuleEngine.explain(ssid: nil, in: c) == .fallback(.noSSID), "nil")
        t.expectTrue(RuleEngine.explain(ssid: "", in: c) == .fallback(.noSSID), "empty")
    }

    r.run("RuleEngine.explain: no matching rule → .fallback(.noRuleMatched)") { t in
        let c = cfg(rules: [Rule(ssid: "Home", location: "HomeLoc")])
        t.expectTrue(RuleEngine.explain(ssid: "Cafe", in: c) == .fallback(.noRuleMatched), "no match")
    }

    r.run("RuleEngine.explain: case-insensitive match preserved") { t in
        let c = cfg(rules: [Rule(ssid: "Home-WiFi", location: "HomeLoc")])
        let res = RuleEngine.explain(ssid: "home-wifi", in: c)
        t.expectTrue(res.targetLocation == "HomeLoc", "resolved target")
    }
}

// MARK: - Config

func configTests(_ r: Runner) {
    func makeTempStore() -> ConfigStore {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LocationChangerTests-\(UUID().uuidString)", isDirectory: true)
        return ConfigStore(
            directoryURL: tmp,
            fileURL: tmp.appendingPathComponent("config.json", isDirectory: false)
        )
    }
    func cleanup(_ s: ConfigStore) { try? FileManager.default.removeItem(at: s.directoryURL) }

    r.run("Config: codable round-trip") { t in
        let original = Config(
            fallback: "Auto",
            notificationsEnabled: false,
            rules: [Rule(ssid: "Home", location: "HomeLoc"), Rule(ssid: "Work", location: "WorkLoc")]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        t.expectTrue(original == decoded, "equality")
    }

    r.run("Config: load creates default on first run") { t in
        let s = makeTempStore(); defer { cleanup(s) }
        t.expectTrue(!FileManager.default.fileExists(atPath: s.fileURL.path), "pre-existence")
        let cfg = try s.load()
        t.expectTrue(cfg == Config.default, "equals default")
        t.expectTrue(FileManager.default.fileExists(atPath: s.fileURL.path), "post-creation")
    }

    r.run("Config: save + load round-trip") { t in
        let s = makeTempStore(); defer { cleanup(s) }
        let cfg = Config(
            fallback: "Home",
            notificationsEnabled: true,
            rules: [Rule(ssid: "MySSID", location: "MyLocation")]
        )
        try s.save(cfg)
        let loaded = try s.load()
        t.expectTrue(cfg == loaded, "round-trip equality")
    }

    r.run("Config: save is atomic (overwrite)") { t in
        let s = makeTempStore(); defer { cleanup(s) }
        try s.save(Config.default)
        t.expectTrue(try s.load() == Config.default, "first load")
        let updated = Config(
            fallback: "Work",
            notificationsEnabled: false,
            rules: [Rule(ssid: "Office", location: "WorkLoc")]
        )
        try s.save(updated)
        t.expectTrue(try s.load() == updated, "second load")
    }

    r.run("Config: load rejects corrupt JSON") { t in
        let s = makeTempStore(); defer { cleanup(s) }
        try FileManager.default.createDirectory(at: s.directoryURL, withIntermediateDirectories: true)
        try Data("not valid json".utf8).write(to: s.fileURL)
        t.expectThrows("decode error") { _ = try s.load() }
    }
}

// MARK: - Main

let r = Runner()
print("LocationChangerTests")
ruleEngineTests(r)
configTests(r)
exit(r.summary())
