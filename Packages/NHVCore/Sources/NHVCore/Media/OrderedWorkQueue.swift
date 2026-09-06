/// FIFO admission with deduplication and a fixed concurrency ceiling.
public struct OrderedWorkQueue<Key: Hashable & Sendable>: Sendable {
    private var pending: [Key] = []
    private var scheduled: Set<Key> = []
    private var active: Set<Key> = []
    private let concurrency: Int

    public init(concurrency: Int) {
        precondition(concurrency > 0)
        self.concurrency = concurrency
    }

    public mutating func enqueue(_ keys: [Key]) {
        for key in keys where scheduled.insert(key).inserted { pending.append(key) }
    }

    public mutating func next() -> Key? {
        guard active.count < concurrency, !pending.isEmpty else { return nil }
        let key = pending.removeFirst()
        active.insert(key)
        return key
    }

    public mutating func finish(_ key: Key) {
        active.remove(key)
        scheduled.remove(key)
    }

    public mutating func removeAll() {
        pending.removeAll()
        scheduled.removeAll()
        active.removeAll()
    }
}
