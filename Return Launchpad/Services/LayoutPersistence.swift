import Foundation

enum LayoutPersistenceError: LocalizedError {
    case invalidDocument
    var errorDescription: String? { "Файл раскладки повреждён или создан более новой версией приложения. Оригинал сохранён." }
}

/// A serial writer preserves commit order. Flush only on actual process termination.
final class LayoutPersistence: @unchecked Sendable {
    let fileURL: URL
    private let writer = DispatchQueue(label: "launchpad.layout.persistence", qos: .utility)
    init(fileURL: URL) { self.fileURL = fileURL }

    func load(legacyDefaults: [UserDefaults] = []) throws -> LayoutDocument {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let document = try JSONDecoder().decode(LayoutDocument.self, from: Data(contentsOf: fileURL))
            guard document.isValid else { throw LayoutPersistenceError.invalidDocument }
            return document
        }
        for defaults in legacyDefaults {
            guard defaults.bool(forKey: "\(NSUserName())_isCustomOrderEnabled"),
                  let json = defaults.string(forKey: "\(NSUserName())_userAppOrder")?.data(using: .utf8),
                  let order = try? JSONDecoder().decode([String].self, from: json) else { continue }
            var seen = Set<String>()
            var document = LayoutDocument()
            document.rootItems = order.filter { !$0.isEmpty && seen.insert($0).inserted }
            document.isCustomized = true
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try json.write(to: fileURL.appendingPathExtension("legacy-backup"), options: .atomic)
            return document
        }
        return LayoutDocument()
    }

    func save(_ document: LayoutDocument, completion: @escaping @Sendable (String?) -> Void = { _ in }) {
        writer.async { [fileURL] in
            do {
                guard document.isValid else { throw LayoutPersistenceError.invalidDocument }
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(document).write(to: fileURL, options: .atomic)
                completion(nil)
            } catch { completion(error.localizedDescription) }
        }
    }
    func flush() { writer.sync {} }
}
