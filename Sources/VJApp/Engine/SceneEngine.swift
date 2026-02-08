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

    var activeScene: Scene? {
        guard project.scenes.indices.contains(activeSceneIndex) else { return nil }
        return project.scenes[activeSceneIndex]
    }

    var transitionScene: Scene? {
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
}
