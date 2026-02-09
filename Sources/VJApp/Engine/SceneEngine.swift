import Foundation
import AVFoundation
import CoreVideo

final class SceneEngine: ObservableObject {
    @Published private(set) var project: Project
    @Published var activeSceneIndex: Int = 0
    @Published var transitionSceneIndex: Int? = nil
    @Published var crossfadeTime: TimeInterval = 0.5
    @Published var crossfadeProgress: Float = 0.0
    @Published var currentPlaybackTime: Double = 0
    @Published var currentDuration: Double = 0

    private var transitionStart: Date?
    private var transitionTimer: Timer?

    /// Video decoders keyed by media ID.
    private var decoders: [String: VideoDecoder] = [:]
    /// Frame queues keyed by media ID.
    private var frameQueues: [String: FrameQueue] = [:]
    /// Latest pixel buffers keyed by media ID for the renderer.
    private(set) var latestPixelBuffers: [String: CVPixelBuffer] = [:]

    private var playbackTimer: Timer?

    init(project: Project) {
        self.project = project
        startPlaybackTimer()
    }

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.pullFrames()
            self?.updatePlaybackTime()
        }
    }

    private func pullFrames() {
        for (mediaId, queue) in frameQueues {
            if let buffer = queue.dequeue() {
                latestPixelBuffers[mediaId] = buffer
            }
        }
    }

    private func updatePlaybackTime() {
        guard let scene = activeScene, let firstLayer = scene.layers.first else {
            currentPlaybackTime = 0
            currentDuration = 0
            return
        }
        if let decoder = decoders[firstLayer.mediaId] {
            currentPlaybackTime = decoder.currentTime
            currentDuration = decoder.duration
        }
    }

    // MARK: - Decoder Management

    func ensureDecoder(for mediaItem: MediaItem) {
        guard decoders[mediaItem.id] == nil else { return }
        let path = mediaItem.resolvedPath ?? mediaItem.path
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return }
        let queue = FrameQueue(capacity: 8)
        let decoder = VideoDecoder(url: url, frameQueue: queue)
        decoders[mediaItem.id] = decoder
        frameQueues[mediaItem.id] = queue
    }

    func startDecodersForActiveScene() {
        guard let scene = activeScene else { return }
        for layer in scene.layers {
            if let mediaItem = project.media.first(where: { $0.id == layer.mediaId }) {
                ensureDecoder(for: mediaItem)
                if layer.playback.state == .playing {
                    decoders[layer.mediaId]?.play()
                }
            }
        }
    }

    func seekAllLayers(to time: Double) {
        guard project.scenes.indices.contains(activeSceneIndex) else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        for layer in project.scenes[activeSceneIndex].layers {
            decoders[layer.mediaId]?.seek(to: cmTime)
        }
        currentPlaybackTime = time
    }

    var activeScene: VJScene? {
        guard project.scenes.indices.contains(activeSceneIndex) else { return nil }
        return project.scenes[activeSceneIndex]
    }

    var transitionScene: VJScene? {
        guard let index = transitionSceneIndex, project.scenes.indices.contains(index) else { return nil }
        return project.scenes[index]
    }

    func triggerScene(index: Int) {
        guard project.scenes.indices.contains(index), index != activeSceneIndex else { return }
        transitionSceneIndex = index
        transitionStart = Date()
        crossfadeProgress = 0
        transitionTimer?.invalidate()
        transitionTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tickTransition()
        }
    }

    func triggerScene(name: String) {
        guard let index = project.scenes.firstIndex(where: { $0.name == name }) else { return }
        triggerScene(index: index)
    }

    func setCrossfadeTime(_ time: TimeInterval) {
        crossfadeTime = max(0.0, time)
    }

    private func tickTransition() {
        guard let start = transitionStart else { return }
        let elapsed = Date().timeIntervalSince(start)
        let progress = min(max(elapsed / crossfadeTime, 0), 1)
        crossfadeProgress = Float(progress)
        if progress >= 1 {
            completeTransition()
        }
    }

    private func completeTransition() {
        if let nextIndex = transitionSceneIndex {
            activeSceneIndex = nextIndex
        }
        transitionSceneIndex = nil
        transitionTimer?.invalidate()
        transitionTimer = nil
    }

    func updateProject(_ project: Project) {
        self.project = project
    }

    // MARK: - Global Transport Controls

    func playAll() {
        guard project.scenes.indices.contains(activeSceneIndex) else { return }
        for i in project.scenes[activeSceneIndex].layers.indices {
            project.scenes[activeSceneIndex].layers[i].playback.state = .playing
        }
    }

    func pauseAll() {
        guard project.scenes.indices.contains(activeSceneIndex) else { return }
        for i in project.scenes[activeSceneIndex].layers.indices {
            project.scenes[activeSceneIndex].layers[i].playback.state = .paused
        }
    }

    func stopAll() {
        guard project.scenes.indices.contains(activeSceneIndex) else { return }
        for i in project.scenes[activeSceneIndex].layers.indices {
            project.scenes[activeSceneIndex].layers[i].playback.state = .stopped
            project.scenes[activeSceneIndex].layers[i].playback.time = 0
        }
    }

    func restartAll() {
        guard project.scenes.indices.contains(activeSceneIndex) else { return }
        for i in project.scenes[activeSceneIndex].layers.indices {
            project.scenes[activeSceneIndex].layers[i].playback.time = 0
            project.scenes[activeSceneIndex].layers[i].playback.state = .playing
        }
    }

    // MARK: - Per-Scene Transport Controls

    func playScene(at sceneIndex: Int) {
        guard project.scenes.indices.contains(sceneIndex) else { return }
        for i in project.scenes[sceneIndex].layers.indices {
            project.scenes[sceneIndex].layers[i].playback.state = .playing
        }
    }

    func pauseScene(at sceneIndex: Int) {
        guard project.scenes.indices.contains(sceneIndex) else { return }
        for i in project.scenes[sceneIndex].layers.indices {
            project.scenes[sceneIndex].layers[i].playback.state = .paused
        }
    }

    func stopScene(at sceneIndex: Int) {
        guard project.scenes.indices.contains(sceneIndex) else { return }
        for i in project.scenes[sceneIndex].layers.indices {
            project.scenes[sceneIndex].layers[i].playback.state = .stopped
            project.scenes[sceneIndex].layers[i].playback.time = 0
        }
    }

    // MARK: - Media Management

    func addMediaItem(_ item: MediaItem) {
        project.media.append(item)
    }

    func removeMediaItem(id: String) {
        project.media.removeAll { $0.id == id }
    }

    // MARK: - Scene Management

    func addScene(name: String) {
        let scene = VJScene(id: UUID().uuidString, name: name, layers: [])
        project.scenes.append(scene)
    }

    func removeScene(id: String) {
        guard let index = project.scenes.firstIndex(where: { $0.id == id }) else { return }
        project.scenes.remove(at: index)
        if activeSceneIndex >= project.scenes.count {
            activeSceneIndex = max(0, project.scenes.count - 1)
        }
    }

    // MARK: - Layer Management

    func addLayer(toSceneIndex sceneIndex: Int, mediaId: String) {
        guard project.scenes.indices.contains(sceneIndex) else { return }
        let layer = LayerInstance(
            id: UUID().uuidString,
            mediaId: mediaId,
            order: project.scenes[sceneIndex].layers.count,
            transform: Transform(position: Vec2(x: 0.5, y: 0.5), scale: Vec2(x: 1, y: 1), rotation: 0, anchor: Vec2(x: 0.5, y: 0.5)),
            opacity: 1.0,
            blendMode: .normal,
            playback: PlaybackSettings(state: .playing, loopMode: .loop, speed: 1.0, time: 0),
            mesh: nil,
            effects: []
        )
        project.scenes[sceneIndex].layers.append(layer)
    }

    func removeLayer(fromSceneIndex sceneIndex: Int, layerId: String) {
        guard project.scenes.indices.contains(sceneIndex) else { return }
        project.scenes[sceneIndex].layers.removeAll { $0.id == layerId }
    }

    func updateLayer(index: Int, _ update: (inout LayerInstance) -> Void) {
        guard project.scenes.indices.contains(activeSceneIndex),
              project.scenes[activeSceneIndex].layers.indices.contains(index) else { return }
        var scene = project.scenes[activeSceneIndex]
        var layer = scene.layers[index]
        update(&layer)
        scene.layers[index] = layer
        project.scenes[activeSceneIndex] = scene
    }

    func updateEffect(layerIndex: Int, effectIndex: Int, _ update: (inout Effect) -> Void) {
        guard project.scenes.indices.contains(activeSceneIndex),
              project.scenes[activeSceneIndex].layers.indices.contains(layerIndex) else { return }
        var scene = project.scenes[activeSceneIndex]
        var layer = scene.layers[layerIndex]
        guard layer.effects.indices.contains(effectIndex) else { return }
        var effect = layer.effects[effectIndex]
        update(&effect)
        layer.effects[effectIndex] = effect
        scene.layers[layerIndex] = layer
        project.scenes[activeSceneIndex] = scene
    }

    // MARK: - Layer Updates by Scene Index

    func updateLayer(sceneIndex: Int, layerIndex: Int, _ update: (inout LayerInstance) -> Void) {
        guard project.scenes.indices.contains(sceneIndex),
              project.scenes[sceneIndex].layers.indices.contains(layerIndex) else { return }
        update(&project.scenes[sceneIndex].layers[layerIndex])
    }

    // MARK: - Effect Management

    func addEffect(sceneIndex: Int, layerIndex: Int, type: EffectType) {
        guard project.scenes.indices.contains(sceneIndex),
              project.scenes[sceneIndex].layers.indices.contains(layerIndex) else { return }
        let defaultParams: [String: EffectParameter]
        switch type {
        case .tint:
            defaultParams = ["color": .float3([1.0, 1.0, 1.0]), "amount": .float(0.0)]
        case .brightnessContrast:
            defaultParams = ["brightness": .float(0.0), "contrast": .float(1.0)]
        case .saturation:
            defaultParams = ["saturation": .float(1.0)]
        case .hueShift:
            defaultParams = ["hueShift": .float(0.0)]
        }
        let effect = Effect(id: UUID().uuidString, type: type, enabled: true, parameters: defaultParams)
        project.scenes[sceneIndex].layers[layerIndex].effects.append(effect)
    }

    func removeEffect(sceneIndex: Int, layerIndex: Int, effectId: String) {
        guard project.scenes.indices.contains(sceneIndex),
              project.scenes[sceneIndex].layers.indices.contains(layerIndex) else { return }
        project.scenes[sceneIndex].layers[layerIndex].effects.removeAll { $0.id == effectId }
    }

    func updateEffect(sceneIndex: Int, layerIndex: Int, effectId: String, _ update: (inout Effect) -> Void) {
        guard project.scenes.indices.contains(sceneIndex),
              project.scenes[sceneIndex].layers.indices.contains(layerIndex) else { return }
        guard let effectIndex = project.scenes[sceneIndex].layers[layerIndex].effects.firstIndex(where: { $0.id == effectId }) else { return }
        update(&project.scenes[sceneIndex].layers[layerIndex].effects[effectIndex])
    }
}
