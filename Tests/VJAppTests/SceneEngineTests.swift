import XCTest
@testable import VJApp

final class SceneEngineTests: XCTestCase {

    // MARK: - Scene Activation

    func testInitialActiveSceneIndex() {
        let engine = makeEngine(sceneCount: 3)
        XCTAssertEqual(engine.activeSceneIndex, 0)
    }

    func testActiveSceneReturnsCorrectScene() {
        let engine = makeEngine(sceneCount: 3)
        let scene = engine.activeScene
        XCTAssertNotNil(scene)
        XCTAssertEqual(scene?.name, "Scene 0")
    }

    func testActiveSceneNilWhenNoScenes() {
        let engine = makeEngine(sceneCount: 0)
        XCTAssertNil(engine.activeScene)
    }

    func testTriggerSceneByIndex() {
        let engine = makeEngine(sceneCount: 3)
        engine.triggerScene(index: 2)
        // Transition should have started
        XCTAssertEqual(engine.transitionSceneIndex, 2)
    }

    func testTriggerSceneByName() {
        let engine = makeEngine(sceneCount: 3)
        engine.triggerScene(name: "Scene 1")
        XCTAssertEqual(engine.transitionSceneIndex, 1)
    }

    func testTriggerSceneByNameNotFound() {
        let engine = makeEngine(sceneCount: 3)
        engine.triggerScene(name: "Nonexistent")
        XCTAssertNil(engine.transitionSceneIndex)
    }

    func testTriggerSameSceneIgnored() {
        let engine = makeEngine(sceneCount: 3)
        engine.triggerScene(index: 0)
        XCTAssertNil(engine.transitionSceneIndex)
    }

    func testTriggerInvalidIndexIgnored() {
        let engine = makeEngine(sceneCount: 3)
        engine.triggerScene(index: 10)
        XCTAssertNil(engine.transitionSceneIndex)
    }

    func testTriggerNegativeIndexIgnored() {
        let engine = makeEngine(sceneCount: 3)
        engine.triggerScene(index: -1)
        XCTAssertNil(engine.transitionSceneIndex)
    }

    // MARK: - Crossfade

    func testCrossfadeInitialProgress() {
        let engine = makeEngine(sceneCount: 3)
        XCTAssertEqual(engine.crossfadeProgress, 0.0)
    }

    func testCrossfadeTimeDefault() {
        let engine = makeEngine(sceneCount: 3)
        XCTAssertEqual(engine.crossfadeTime, 0.5, accuracy: 0.01)
    }

    func testSetCrossfadeTime() {
        let engine = makeEngine(sceneCount: 3)
        engine.setCrossfadeTime(1.5)
        XCTAssertEqual(engine.crossfadeTime, 1.5, accuracy: 0.01)
    }

    func testSetCrossfadeTimeNegativeClamped() {
        let engine = makeEngine(sceneCount: 3)
        engine.setCrossfadeTime(-1.0)
        XCTAssertEqual(engine.crossfadeTime, 0.0, accuracy: 0.01)
    }

    func testTransitionSceneReturnedDuringCrossfade() {
        let engine = makeEngine(sceneCount: 3)
        engine.triggerScene(index: 1)
        let transScene = engine.transitionScene
        XCTAssertNotNil(transScene)
        XCTAssertEqual(transScene?.name, "Scene 1")
    }

    func testTransitionSceneNilWhenNoTransition() {
        let engine = makeEngine(sceneCount: 3)
        XCTAssertNil(engine.transitionScene)
    }

    // MARK: - Layer Updates

    func testUpdateLayer() {
        let engine = makeEngine(sceneCount: 1)
        engine.updateLayer(index: 0) { layer in
            layer.opacity = 0.5
        }
        XCTAssertEqual(engine.activeScene?.layers[0].opacity, 0.5, accuracy: 0.001)
    }

    func testUpdateLayerInvalidIndex() {
        let engine = makeEngine(sceneCount: 1)
        // Should not crash
        engine.updateLayer(index: 99) { layer in
            layer.opacity = 0.5
        }
    }

    func testUpdateEffect() {
        let engine = makeEngineWithEffects()
        engine.updateEffect(layerIndex: 0, effectIndex: 0) { effect in
            effect.enabled = false
        }
        let layer = engine.activeScene?.layers[0]
        XCTAssertEqual(layer?.effects[0].enabled, false)
    }

    func testUpdateEffectInvalidIndices() {
        let engine = makeEngineWithEffects()
        // Should not crash
        engine.updateEffect(layerIndex: 99, effectIndex: 0) { _ in }
        engine.updateEffect(layerIndex: 0, effectIndex: 99) { _ in }
    }

    func testUpdateProject() {
        let engine = makeEngine(sceneCount: 1)
        var newProject = engine.project
        newProject.projectName = "Updated"
        engine.updateProject(newProject)
        XCTAssertEqual(engine.project.projectName, "Updated")
    }

    // MARK: - Helpers

    private func makeEngine(sceneCount: Int) -> SceneEngine {
        let scenes = (0..<sceneCount).map { i in
            Scene(
                id: "s\(i)",
                name: "Scene \(i)",
                layers: [
                    LayerInstance(
                        id: "l\(i)",
                        mediaId: "m1",
                        order: 0,
                        transform: Transform(position: Vec2(x: 0.5, y: 0.5), scale: Vec2(x: 1, y: 1), rotation: 0, anchor: Vec2(x: 0.5, y: 0.5)),
                        opacity: 1.0,
                        blendMode: .normal,
                        playback: PlaybackSettings(state: .playing, loopMode: .loop, speed: 1.0, time: 0),
                        mesh: nil,
                        effects: []
                    )
                ]
            )
        }
        let project = Project(
            projectName: "Test",
            media: [],
            scenes: scenes,
            output: OutputSettings(displayId: 0, resolution: Resolution(width: 1920, height: 1080), targetFPS: 60),
            osc: OSCSettings(port: 7000, bindings: [])
        )
        return SceneEngine(project: project)
    }

    private func makeEngineWithEffects() -> SceneEngine {
        let layer = LayerInstance(
            id: "l0",
            mediaId: "m1",
            order: 0,
            transform: Transform(position: Vec2(x: 0.5, y: 0.5), scale: Vec2(x: 1, y: 1), rotation: 0, anchor: Vec2(x: 0.5, y: 0.5)),
            opacity: 1.0,
            blendMode: .normal,
            playback: PlaybackSettings(state: .playing, loopMode: .loop, speed: 1.0, time: 0),
            mesh: nil,
            effects: [
                Effect(id: "e0", type: .tint, enabled: true, parameters: [
                    "color": .float3([1.0, 0.0, 0.0]),
                    "amount": .float(0.5)
                ])
            ]
        )
        let project = Project(
            projectName: "Test",
            media: [],
            scenes: [Scene(id: "s0", name: "Scene 0", layers: [layer])],
            output: OutputSettings(displayId: 0, resolution: Resolution(width: 1920, height: 1080), targetFPS: 60),
            osc: OSCSettings(port: 7000, bindings: [])
        )
        return SceneEngine(project: project)
    }
}
