import Foundation

final class SceneEngine: ObservableObject {
    @Published private(set) var project: Project
    @Published var activeSceneIndex: Int = 0
    @Published var transitionSceneIndex: Int? = nil
    @Published var crossfadeTime: TimeInterval = 0.5
    @Published var crossfadeProgress: Float = 0.0

    private var transitionStart: Date?
    private var transitionTimer: Timer?

    init(project: Project) {
        self.project = project
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
}
