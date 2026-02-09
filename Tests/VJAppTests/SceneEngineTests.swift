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
        XCTAssertEqual(engine.activeScene!.layers[0].opacity, Float(0.5), accuracy: Float(0.001))
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

    // MARK: - Media Management

    func testAddMediaItem() {
        let engine = makeEngine(sceneCount: 1)
        let item = MediaItem(
            id: "m1",
            name: "TestVideo",
            path: "/test/video.mp4",
            resolvedPath: nil,
            duration: 10,
            fps: 30,
            resolution: Resolution(width: 1920, height: 1080),
            lastKnownBookmark: nil
        )
        engine.addMediaItem(item)
        XCTAssertEqual(engine.project.media.count, 1)
        XCTAssertEqual(engine.project.media[0].name, "TestVideo")
    }

    func testRemoveMediaItem() {
        let engine = makeEngine(sceneCount: 1)
        let item = MediaItem(
            id: "m1",
            name: "TestVideo",
            path: "/test/video.mp4",
            resolvedPath: nil,
            duration: 10,
            fps: 30,
            resolution: Resolution(width: 1920, height: 1080),
            lastKnownBookmark: nil
        )
        engine.addMediaItem(item)
        XCTAssertEqual(engine.project.media.count, 1)
        engine.removeMediaItem(id: "m1")
        XCTAssertEqual(engine.project.media.count, 0)
    }

    func testRemoveMediaItemNotFound() {
        let engine = makeEngine(sceneCount: 1)
        engine.removeMediaItem(id: "nonexistent")
        XCTAssertEqual(engine.project.media.count, 0)
    }

    // MARK: - Scene Management

    func testAddScene() {
        let engine = makeEngine(sceneCount: 0)
        engine.addScene(name: "New Scene")
        XCTAssertEqual(engine.project.scenes.count, 1)
        XCTAssertEqual(engine.project.scenes[0].name, "New Scene")
        XCTAssertTrue(engine.project.scenes[0].layers.isEmpty)
    }

    func testRemoveScene() {
        let engine = makeEngine(sceneCount: 3)
        let sceneId = engine.project.scenes[1].id
        engine.removeScene(id: sceneId)
        XCTAssertEqual(engine.project.scenes.count, 2)
        XCTAssertNil(engine.project.scenes.first(where: { $0.id == sceneId }))
    }

    func testRemoveSceneAdjustsActiveIndex() {
        let engine = makeEngine(sceneCount: 2)
        engine.triggerScene(index: 1)
        // Complete the transition manually
        engine.updateProject(engine.project)
        let sceneId = engine.project.scenes[1].id
        engine.removeScene(id: sceneId)
        XCTAssertEqual(engine.project.scenes.count, 1)
        XCTAssertTrue(engine.activeSceneIndex < engine.project.scenes.count || engine.project.scenes.isEmpty)
    }

    func testRemoveSceneNotFound() {
        let engine = makeEngine(sceneCount: 2)
        engine.removeScene(id: "nonexistent")
        XCTAssertEqual(engine.project.scenes.count, 2)
    }

    // MARK: - Layer Management

    func testAddLayerToScene() {
        let engine = makeEngine(sceneCount: 1)
        let initialLayerCount = engine.project.scenes[0].layers.count
        engine.addLayer(toSceneIndex: 0, mediaId: "m1")
        XCTAssertEqual(engine.project.scenes[0].layers.count, initialLayerCount + 1)
    }

    func testAddLayerInvalidSceneIndex() {
        let engine = makeEngine(sceneCount: 1)
        // Should not crash
        engine.addLayer(toSceneIndex: 99, mediaId: "m1")
    }

    func testRemoveLayerFromScene() {
        let engine = makeEngine(sceneCount: 1)
        let layerId = engine.project.scenes[0].layers[0].id
        engine.removeLayer(fromSceneIndex: 0, layerId: layerId)
        XCTAssertEqual(engine.project.scenes[0].layers.count, 0)
    }

    func testRemoveLayerInvalidSceneIndex() {
        let engine = makeEngine(sceneCount: 1)
        // Should not crash
        engine.removeLayer(fromSceneIndex: 99, layerId: "l0")
    }

    // MARK: - Global Transport Controls

    func testPlayAll() {
        let engine = makeEngine(sceneCount: 1)
        engine.pauseAll()
        XCTAssertEqual(engine.project.scenes[0].layers[0].playback.state, .paused)
        engine.playAll()
        XCTAssertEqual(engine.project.scenes[0].layers[0].playback.state, .playing)
    }

    func testPauseAll() {
        let engine = makeEngine(sceneCount: 1)
        engine.pauseAll()
        XCTAssertEqual(engine.project.scenes[0].layers[0].playback.state, .paused)
    }

    func testStopAll() {
        let engine = makeEngine(sceneCount: 1)
        engine.stopAll()
        XCTAssertEqual(engine.project.scenes[0].layers[0].playback.state, .stopped)
        XCTAssertEqual(engine.project.scenes[0].layers[0].playback.time, 0)
    }

    func testRestartAll() {
        let engine = makeEngine(sceneCount: 1)
        engine.pauseAll()
        engine.restartAll()
        XCTAssertEqual(engine.project.scenes[0].layers[0].playback.state, .playing)
        XCTAssertEqual(engine.project.scenes[0].layers[0].playback.time, 0)
    }

    func testPlayAllNoScenes() {
        let engine = makeEngine(sceneCount: 0)
        // Should not crash
        engine.playAll()
        engine.pauseAll()
        engine.stopAll()
        engine.restartAll()
    }

    // MARK: - Per-Scene Transport Controls

    func testPlayScene() {
        let engine = makeEngine(sceneCount: 2)
        engine.pauseScene(at: 1)
        XCTAssertEqual(engine.project.scenes[1].layers[0].playback.state, .paused)
        engine.playScene(at: 1)
        XCTAssertEqual(engine.project.scenes[1].layers[0].playback.state, .playing)
    }

    func testPauseScene() {
        let engine = makeEngine(sceneCount: 2)
        engine.pauseScene(at: 0)
        XCTAssertEqual(engine.project.scenes[0].layers[0].playback.state, .paused)
        // Other scene should remain unaffected
        XCTAssertEqual(engine.project.scenes[1].layers[0].playback.state, .playing)
    }

    func testStopScene() {
        let engine = makeEngine(sceneCount: 2)
        engine.stopScene(at: 0)
        XCTAssertEqual(engine.project.scenes[0].layers[0].playback.state, .stopped)
        XCTAssertEqual(engine.project.scenes[0].layers[0].playback.time, 0)
        // Other scene should remain unaffected
        XCTAssertEqual(engine.project.scenes[1].layers[0].playback.state, .playing)
    }

    func testPerSceneTransportInvalidIndex() {
        let engine = makeEngine(sceneCount: 1)
        // Should not crash
        engine.playScene(at: 99)
        engine.pauseScene(at: -1)
        engine.stopScene(at: 99)
    }

    // MARK: - Layer Update by Scene Index

    func testUpdateLayerBySceneIndex() {
        let engine = makeEngine(sceneCount: 2)
        engine.updateLayer(sceneIndex: 1, layerIndex: 0) { layer in
            layer.opacity = 0.3
        }
        XCTAssertEqual(engine.project.scenes[1].layers[0].opacity, Float(0.3), accuracy: Float(0.001))
        // Scene 0 should not be affected
        XCTAssertEqual(engine.project.scenes[0].layers[0].opacity, Float(1.0), accuracy: Float(0.001))
    }

    func testUpdateLayerBySceneIndexInvalidScene() {
        let engine = makeEngine(sceneCount: 1)
        // Should not crash
        engine.updateLayer(sceneIndex: 99, layerIndex: 0) { layer in
            layer.opacity = 0.5
        }
    }

    func testUpdateLayerBySceneIndexInvalidLayer() {
        let engine = makeEngine(sceneCount: 1)
        // Should not crash
        engine.updateLayer(sceneIndex: 0, layerIndex: 99) { layer in
            layer.opacity = 0.5
        }
    }

    func testUpdateLayerTransformPosition() {
        let engine = makeEngine(sceneCount: 1)
        engine.updateLayer(sceneIndex: 0, layerIndex: 0) { layer in
            layer.transform.position = Vec2(x: 0.2, y: 0.8)
        }
        XCTAssertEqual(engine.project.scenes[0].layers[0].transform.position.x, Float(0.2), accuracy: Float(0.001))
        XCTAssertEqual(engine.project.scenes[0].layers[0].transform.position.y, Float(0.8), accuracy: Float(0.001))
    }

    func testUpdateLayerTransformScale() {
        let engine = makeEngine(sceneCount: 1)
        engine.updateLayer(sceneIndex: 0, layerIndex: 0) { layer in
            layer.transform.scale = Vec2(x: 2.0, y: 0.5)
        }
        XCTAssertEqual(engine.project.scenes[0].layers[0].transform.scale.x, Float(2.0), accuracy: Float(0.001))
        XCTAssertEqual(engine.project.scenes[0].layers[0].transform.scale.y, Float(0.5), accuracy: Float(0.001))
    }

    // MARK: - Effect Management

    func testAddEffectTint() {
        let engine = makeEngine(sceneCount: 1)
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects.count, 0)
        engine.addEffect(sceneIndex: 0, layerIndex: 0, type: .tint)
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects.count, 1)
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects[0].type, .tint)
        XCTAssertTrue(engine.project.scenes[0].layers[0].effects[0].enabled)
        XCTAssertNotNil(engine.project.scenes[0].layers[0].effects[0].parameters["color"])
        XCTAssertNotNil(engine.project.scenes[0].layers[0].effects[0].parameters["amount"])
    }

    func testAddEffectBrightnessContrast() {
        let engine = makeEngine(sceneCount: 1)
        engine.addEffect(sceneIndex: 0, layerIndex: 0, type: .brightnessContrast)
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects.count, 1)
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects[0].type, .brightnessContrast)
        XCTAssertNotNil(engine.project.scenes[0].layers[0].effects[0].parameters["brightness"])
        XCTAssertNotNil(engine.project.scenes[0].layers[0].effects[0].parameters["contrast"])
    }

    func testAddEffectSaturation() {
        let engine = makeEngine(sceneCount: 1)
        engine.addEffect(sceneIndex: 0, layerIndex: 0, type: .saturation)
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects.count, 1)
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects[0].type, .saturation)
        XCTAssertNotNil(engine.project.scenes[0].layers[0].effects[0].parameters["saturation"])
    }

    func testAddEffectHueShift() {
        let engine = makeEngine(sceneCount: 1)
        engine.addEffect(sceneIndex: 0, layerIndex: 0, type: .hueShift)
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects.count, 1)
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects[0].type, .hueShift)
        XCTAssertNotNil(engine.project.scenes[0].layers[0].effects[0].parameters["hueShift"])
    }

    func testAddMultipleEffects() {
        let engine = makeEngine(sceneCount: 1)
        engine.addEffect(sceneIndex: 0, layerIndex: 0, type: .tint)
        engine.addEffect(sceneIndex: 0, layerIndex: 0, type: .saturation)
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects.count, 2)
    }

    func testAddEffectInvalidSceneIndex() {
        let engine = makeEngine(sceneCount: 1)
        // Should not crash
        engine.addEffect(sceneIndex: 99, layerIndex: 0, type: .tint)
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects.count, 0)
    }

    func testAddEffectInvalidLayerIndex() {
        let engine = makeEngine(sceneCount: 1)
        // Should not crash
        engine.addEffect(sceneIndex: 0, layerIndex: 99, type: .tint)
    }

    func testRemoveEffect() {
        let engine = makeEngine(sceneCount: 1)
        engine.addEffect(sceneIndex: 0, layerIndex: 0, type: .tint)
        let effectId = engine.project.scenes[0].layers[0].effects[0].id
        engine.removeEffect(sceneIndex: 0, layerIndex: 0, effectId: effectId)
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects.count, 0)
    }

    func testRemoveEffectNotFound() {
        let engine = makeEngine(sceneCount: 1)
        engine.addEffect(sceneIndex: 0, layerIndex: 0, type: .tint)
        // Should not crash, and should not remove the existing effect
        engine.removeEffect(sceneIndex: 0, layerIndex: 0, effectId: "nonexistent")
        XCTAssertEqual(engine.project.scenes[0].layers[0].effects.count, 1)
    }

    func testRemoveEffectInvalidIndices() {
        let engine = makeEngine(sceneCount: 1)
        // Should not crash
        engine.removeEffect(sceneIndex: 99, layerIndex: 0, effectId: "e0")
        engine.removeEffect(sceneIndex: 0, layerIndex: 99, effectId: "e0")
    }

    func testUpdateEffectBySceneAndId() {
        let engine = makeEngine(sceneCount: 1)
        engine.addEffect(sceneIndex: 0, layerIndex: 0, type: .tint)
        let effectId = engine.project.scenes[0].layers[0].effects[0].id
        engine.updateEffect(sceneIndex: 0, layerIndex: 0, effectId: effectId) { effect in
            effect.enabled = false
            effect.parameters["amount"] = .float(0.8)
        }
        let updatedEffect = engine.project.scenes[0].layers[0].effects[0]
        XCTAssertFalse(updatedEffect.enabled)
        if case .float(let amount) = updatedEffect.parameters["amount"] {
            XCTAssertEqual(amount, Float(0.8), accuracy: Float(0.001))
        } else {
            XCTFail("Expected float parameter for amount")
        }
    }

    func testUpdateEffectBySceneAndIdNotFound() {
        let engine = makeEngine(sceneCount: 1)
        engine.addEffect(sceneIndex: 0, layerIndex: 0, type: .tint)
        // Should not crash
        engine.updateEffect(sceneIndex: 0, layerIndex: 0, effectId: "nonexistent") { effect in
            effect.enabled = false
        }
        // Original effect should be unchanged
        XCTAssertTrue(engine.project.scenes[0].layers[0].effects[0].enabled)
    }

    func testSeekAllLayersInvalidIndex() {
        let engine = makeEngine(sceneCount: 0)
        // Should not crash with no scenes
        engine.seekAllLayers(to: 5.0)
    }

    // MARK: - Helpers

    private func makeEngine(sceneCount: Int) -> SceneEngine {
        let scenes = (0..<sceneCount).map { i in
            VJScene(
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
            scenes: [VJScene(id: "s0", name: "Scene 0", layers: [layer])],
            output: OutputSettings(displayId: 0, resolution: Resolution(width: 1920, height: 1080), targetFPS: 60),
            osc: OSCSettings(port: 7000, bindings: [])
        )
        return SceneEngine(project: project)
    }
}
