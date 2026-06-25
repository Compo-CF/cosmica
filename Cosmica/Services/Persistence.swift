import Foundation

/// Saves the full `GameState` to a single JSON file in the app's Documents directory.
/// Atomic writes prevent corruption from a crash mid-save.
final class Persistence {
    private let url: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    init(filename: String = "cosmica.save.json") throws {
        let dir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.url = dir.appendingPathComponent(filename)
    }

    private init(memoryURL: URL) {
        self.url = memoryURL
    }

    /// Fallback for environments where Documents isn't available (unit tests, previews).
    static func inMemory() -> Persistence {
        Persistence(memoryURL: FileManager.default.temporaryDirectory.appendingPathComponent("cosmica.preview.json"))
    }

    func load() -> GameState {
        guard let data = try? Data(contentsOf: url),
              let state = try? decoder.decode(GameState.self, from: data)
        else { return GameState() }
        return state
    }

    func save(state: GameState) throws {
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
    }

    func reset() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
