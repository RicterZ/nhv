/// FIFO admission with deduplication and a fixed concurrency ceiling.
public struct OrderedWorkQueue<Key: Hashable & Sendable>: Sendable {
    private var pending: [Key] = []
    private var scheduled: Set<Key> = []
    private var active: Set<Key> = []
    private let concurrency: Int
    private let batchSize: Int?
    private var startedInBatch = 0

    public init(concurrency: Int, batchSize: Int? = nil) {
        precondition(concurrency > 0)
        precondition(batchSize == nil || batchSize! > 0)
        self.concurrency = concurrency
        self.batchSize = batchSize
    }

    public mutating func enqueue(_ keys: [Key]) {
        for key in keys where scheduled.insert(key).inserted { pending.append(key) }
    }

    public mutating func next() -> Key? {
        guard active.count < concurrency, !pending.isEmpty else { return nil }
        if let batchSize, startedInBatch >= batchSize {
            guard active.isEmpty else { return nil }
            startedInBatch = 0
        }
        let key = pending.removeFirst()
        active.insert(key)
        startedInBatch += 1
        return key
    }

    public mutating func finish(_ key: Key) {
        active.remove(key)
        scheduled.remove(key)
        if pending.isEmpty && active.isEmpty { startedInBatch = 0 }
    }

    public mutating func removeAll() {
        pending.removeAll()
        scheduled.removeAll()
        active.removeAll()
        startedInBatch = 0
    }
}
