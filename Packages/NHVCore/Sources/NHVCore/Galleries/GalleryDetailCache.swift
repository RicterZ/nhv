import Foundation

/// Immutable gallery metadata is loaded locally until explicitly refreshed.
public actor GalleryDetailCache {
    public static let shared = GalleryDetailCache()
    private let storageDirectory: URL?
    private var pending: [Int: Task<GalleryDetail, any Error>] = [:]
    private var generation = UUID()

    public init(directory: URL? = nil) { storageDirectory = directory }

    public func gallery(id: Int, api: NHentaiAPI, refresh: Bool = false) async throws -> GalleryDetail {
        guard id > 0 else { throw APIError.invalidInput(.identifier) }
        let file = try? directory().appendingPathComponent("\(id).json")
        if !refresh, let file, let data = try? Data(contentsOf: file),
           let cached = try? JSONDecoder().decode(GalleryDetail.self, from: data), cached.id == id {
            return cached
        }
        if let task = pending[id] { return try await task.value }
        let operation = generation
        let task = Task { try await api.gallery(id: id) }
        pending[id] = task
        defer { if operation == generation { pending[id] = nil } }
        let result = try await task.value
        guard operation == generation else { throw CancellationError() }
        // Favorite status belongs to the current account, never the disk cache.
        if let file, let data = try? JSONEncoder().encode(result),
           var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            object.removeValue(forKey: "isFavorited")
            if let data = try? JSONSerialization.data(withJSONObject: object) {
                try? data.write(to: file, options: .atomic)
            }
        }
        return result
    }

    public func sizeInBytes() throws -> Int64 {
        try FileManager.default.contentsOfDirectory(at: directory(), includingPropertiesForKeys: [.fileSizeKey])
            .reduce(0) { try $0 + Int64($1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
    }

    public func clear() throws {
        generation = UUID()
        pending.values.forEach { $0.cancel() }
        pending.removeAll()
        try FileManager.default.removeItem(at: directory())
    }

    private func directory() throws -> URL {
        var url: URL
        if let storageDirectory { url = storageDirectory }
        else {
            url = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true).appendingPathComponent("GalleryDetails", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        return url
    }
}
