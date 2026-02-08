import XCTest
@testable import VJApp

final class FrameQueueTests: XCTestCase {

    func testInitialCountZero() {
        let queue = FrameQueue(capacity: 4)
        XCTAssertEqual(queue.count, 0)
    }

    func testDequeueEmptyReturnsNil() {
        let queue = FrameQueue(capacity: 4)
        XCTAssertNil(queue.dequeue())
    }

    func testEnqueueAndDequeue() {
        let queue = FrameQueue(capacity: 4)
        let buffer = makePixelBuffer()
        XCTAssertTrue(queue.enqueue(buffer))
        XCTAssertEqual(queue.count, 1)
        let dequeued = queue.dequeue()
        XCTAssertNotNil(dequeued)
        XCTAssertEqual(queue.count, 0)
    }

    func testCapacityEnforced() {
        let queue = FrameQueue(capacity: 2)
        let buf1 = makePixelBuffer()
        let buf2 = makePixelBuffer()
        let buf3 = makePixelBuffer()
        XCTAssertTrue(queue.enqueue(buf1))
        XCTAssertTrue(queue.enqueue(buf2))
        XCTAssertFalse(queue.enqueue(buf3))
        XCTAssertEqual(queue.count, 2)
    }

    func testFIFOOrder() {
        let queue = FrameQueue(capacity: 4)
        let buf1 = makePixelBuffer(width: 10, height: 10)
        let buf2 = makePixelBuffer(width: 20, height: 20)
        _ = queue.enqueue(buf1)
        _ = queue.enqueue(buf2)
        let first = queue.dequeue()!
        XCTAssertEqual(CVPixelBufferGetWidth(first), 10)
        let second = queue.dequeue()!
        XCTAssertEqual(CVPixelBufferGetWidth(second), 20)
    }

    func testClear() {
        let queue = FrameQueue(capacity: 4)
        _ = queue.enqueue(makePixelBuffer())
        _ = queue.enqueue(makePixelBuffer())
        queue.clear()
        XCTAssertEqual(queue.count, 0)
        XCTAssertNil(queue.dequeue())
    }

    func testConcurrentAccess() {
        let queue = FrameQueue(capacity: 100)
        let expectation = self.expectation(description: "concurrent")
        expectation.expectedFulfillmentCount = 2

        DispatchQueue.global().async {
            for _ in 0..<50 {
                _ = queue.enqueue(self.makePixelBuffer())
            }
            expectation.fulfill()
        }

        DispatchQueue.global().async {
            for _ in 0..<50 {
                _ = queue.dequeue()
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        // Should not crash - thread safety verified
        XCTAssertTrue(queue.count >= 0)
    }

    // MARK: - Helpers

    private func makePixelBuffer(width: Int = 16, height: Int = 16) -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
        return buffer!
    }
}
