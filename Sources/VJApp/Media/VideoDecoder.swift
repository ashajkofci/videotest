import AVFoundation
import CoreVideo

final class VideoDecoder {
    private let asset: AVAsset
    private let output: AVPlayerItemVideoOutput
    private let playerItem: AVPlayerItem
    private let player: AVPlayer
    private let frameQueue: FrameQueue
    private let decodeQueue = DispatchQueue(label: "decoder.queue", qos: .userInitiated)
    private var displayLink: CADisplayLink?
    private var isRunning = false

    init(url: URL, frameQueue: FrameQueue) {
        self.asset = AVAsset(url: url)
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        self.output = AVPlayerItemVideoOutput(pixelBufferAttributes: attrs)
        self.playerItem = AVPlayerItem(asset: asset)
        self.playerItem.add(output)
        self.player = AVPlayer(playerItem: playerItem)
        self.frameQueue = frameQueue
    }

    func play() {
        player.play()
        startPullingFrames()
    }

    func pause() {
        player.pause()
    }

    func stop() {
        player.pause()
        player.seek(to: .zero)
        frameQueue.clear()
    }

    func seek(to time: CMTime) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setRate(_ rate: Float) {
        player.rate = rate
    }

    private func startPullingFrames() {
        guard !isRunning else { return }
        isRunning = true
        decodeQueue.async { [weak self] in
            guard let self else { return }
            while self.isRunning {
                let hostTime = CACurrentMediaTime()
                let itemTime = self.output.itemTime(forHostTime: hostTime)
                guard self.output.hasNewPixelBuffer(forItemTime: itemTime),
                      let buffer = self.output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) else {
                    Thread.sleep(forTimeInterval: 0.002)
                    continue
                }
                if !self.frameQueue.enqueue(buffer) {
                    Thread.sleep(forTimeInterval: 0.001)
                }
            }
        }
    }

    func shutdown() {
        isRunning = false
    }
}
