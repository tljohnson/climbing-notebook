import Foundation

struct Report: Decodable {
    struct Target: Decodable {
        let name: String
        let files: [File]
    }
    struct File: Decodable {
        let path: String
        let coveredLines: Int
        let executableLines: Int
    }
    let targets: [Target]
}

func check(_ data: Data) throws -> Bool {
    let report = try JSONDecoder().decode(Report.self, from: data)
    var covered = 0, executable = 0
    for name in ["ClimbingNotebook.app", "ClimbingNotebookShare.appex"] {
        guard let target = report.targets.first(where: { $0.name == name }) else {
            throw NSError(domain: "CoverageGate", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing first-party target: \(name)"])
        }
        var targetCovered = 0, targetExecutable = 0
        for file in target.files where file.path.hasSuffix(".swift") {
            guard !file.path.contains("/SourcePackages/"), !file.path.contains("/DerivedSources/") else { continue }
            targetCovered += file.coveredLines
            targetExecutable += file.executableLines
        }
        guard targetExecutable > 0, targetCovered >= 0, targetCovered <= targetExecutable else {
            throw NSError(domain: "CoverageGate", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid or empty coverage for \(name)"])
        }
        print("\(name): \(targetCovered)/\(targetExecutable)")
        covered += targetCovered
        executable += targetExecutable
    }
    let percent = Double(covered) / Double(executable) * 100
    print(String(format: "First-party total: %d/%d (%.2f%%); required >=70%%", covered, executable, percent))
    return covered * 100 >= executable * 70
}

do {
    let arguments = CommandLine.arguments
    if arguments.count == 2 && arguments[1] == "--self-test" {
        let below = Data("""
        {"targets":[
          {"name":"ClimbingNotebook.app","files":[{"path":"/src/App.swift","coveredLines":6,"executableLines":10}]},
          {"name":"ClimbingNotebookShare.appex","files":[{"path":"/src/Share.swift","coveredLines":0,"executableLines":1}]}
        ]}
        """.utf8)
        guard try !check(below) else { fatalError("Below-threshold fixture was accepted") }
        print("PASS: below-threshold sample rejected")
        exit(0)
    }
    guard arguments.count == 2 else {
        throw NSError(domain: "CoverageGate", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "Usage: CoverageGate.swift <xcresult> | --self-test"])
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["xccov", "view", "--report", "--json", arguments[1]]
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { exit(process.terminationStatus) }
    exit(try check(data) ? 0 : 1)
} catch {
    fputs("Coverage failure: \(error.localizedDescription)\n", stderr)
    exit(1)
}
