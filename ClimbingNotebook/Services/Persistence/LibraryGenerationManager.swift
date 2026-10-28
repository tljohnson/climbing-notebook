import Foundation

/// Filesystem feasibility harness. Call only with no live store contexts or workers.
@MainActor
struct LibraryGenerationManager {
    enum Phase: String, Codable, CaseIterable { case prepared, switched }
    enum Checkpoint: CaseIterable { case prepared, descriptorSwitched, switched }
    enum Failure: Error { case invalidGeneration, recoveryRequired, interrupted }
    struct Journal: Codable {
        let previous: UUID
        let replacement: UUID
        let phase: Phase
    }

    let root: URL
    private var descriptor: URL { root.appendingPathComponent("active.json") }
    private var journalURL: URL { root.appendingPathComponent("replacement.json") }

    func storeURL(_ id: UUID) -> URL {
        root.appendingPathComponent("Libraries").appendingPathComponent(id.uuidString)
            .appendingPathComponent("library.store")
    }

    func initialize(_ id: UUID) throws {
        try requireNoPendingRecovery()
        guard !FileManager.default.fileExists(atPath: descriptor.path) else {
            throw Failure.invalidGeneration
        }
        try validate(id)
        try write(id, to: descriptor)
    }

    func active() throws -> UUID {
        try JSONDecoder().decode(UUID.self, from: Data(contentsOf: descriptor))
    }

    func replace(with next: UUID, interruptAfter: Checkpoint? = nil) throws {
        try requireNoPendingRecovery()
        let previous = try active()
        guard next != previous else { throw Failure.invalidGeneration }
        try validate(previous)
        try validate(next)
        try write(Journal(previous: previous, replacement: next, phase: .prepared), to: journalURL)
        if interruptAfter == .prepared { throw Failure.interrupted }
        try write(next, to: descriptor)
        if interruptAfter == .descriptorSwitched { throw Failure.interrupted }
        // Recovery also handles a crash between descriptor replacement and this journal write.
        try write(Journal(previous: previous, replacement: next, phase: .switched), to: journalURL)
        if interruptAfter == .switched { throw Failure.interrupted }
        try recover()
    }

    func recover() throws {
        guard FileManager.default.fileExists(atPath: journalURL.path) else {
            try validate(active())
            return
        }
        let journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: journalURL))
        let current = try active()
        guard journal.previous != journal.replacement,
              current == journal.previous || current == journal.replacement else {
            throw Failure.invalidGeneration
        }
        if current == journal.replacement {
            do { try validate(journal.replacement) }
            catch {
                try validate(journal.previous)
                try write(journal.previous, to: descriptor)
            }
        } else {
            try validate(journal.previous)
        }
        try FileManager.default.removeItem(at: journalURL)
    }

    private func validate(_ id: UUID) throws {
        let store = try LibraryStore(url: storeURL(id))
        _ = try store.routeNames()
    }

    private func requireNoPendingRecovery() throws {
        guard !FileManager.default.fileExists(atPath: journalURL.path) else {
            throw Failure.recoveryRequired
        }
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
