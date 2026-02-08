import CoreVideo

final class FrameQueue {
    private var queue: [CVPixelBuffer] = []
    private let capacity: Int
    private let lock = NSLock()

    init(capacity: Int) {
        self.capacity = capacity
    }

    func enqueue(_ buffer: CVPixelBuffer) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard queue.count < capacity else { return false }
        queue.append(buffer)
        return true
    }

    func dequeue() -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        guard !queue.isEmpty else { return nil }
        return queue.removeFirst()
    }

    func clear() {
        lock.lock()
        queue.removeAll()
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return queue.count
    }
}
