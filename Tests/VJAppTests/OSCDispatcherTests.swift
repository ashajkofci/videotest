import XCTest
@testable import VJApp

final class OSCDispatcherTests: XCTestCase {

    // MARK: - Scene Trigger

    func testSceneTriggerByIndex() {
        let (engine, dispatcher) = makeSetup()
        let bindings = [OSCBinding(address: "/scene/trigger", target: .sceneTrigger)]
        let message = OSCMessage(address: "/scene/trigger", arguments: [.int(1)])
        dispatcher.dispatch(message: message, bindings: bindings)
        XCTAssertEqual(engine.transitionSceneIndex, 1)
    }

    func testSceneTriggerByName() {
        let (engine, dispatcher) = makeSetup()
        let bindings = [OSCBinding(address: "/scene/trigger", target: .sceneTrigger)]
        let message = OSCMessage(address: "/scene/trigger", arguments: [.string("Scene 1")])
        dispatcher.dispatch(message: message, bindings: bindings)
        XCTAssertEqual(engine.transitionSceneIndex, 1)
    }

    // MARK: - Crossfade Time

    func testCrossfadeTime() {
        let (engine, dispatcher) = makeSetup()
        let bindings = [OSCBinding(address: "/crossfade", target: .crossfadeTime)]
        let message = OSCMessage(address: "/crossfade", arguments: [.float(2.0)])
        dispatcher.dispatch(message: message, bindings: bindings)
        XCTAssertEqual(engine.crossfadeTime, 2.0, accuracy: 0.01)
    }

    // MARK: - Layer Properties

    func testLayerOpacity() {
        let (engine, dispatcher) = makeSetup()
        let bindings = [OSCBinding(address: "/layer/1/opacity", target: .layerOpacity, layerIndex: 0)]
        let message = OSCMessage(address: "/layer/1/opacity", arguments: [.float(0.7)])
        dispatcher.dispatch(message: message, bindings: bindings)
        XCTAssertEqual(engine.activeScene?.layers[0].opacity, 0.7, accuracy: 0.001)
    }

    func testLayerPosition() {
        let (engine, dispatcher) = makeSetup()
        let bindings = [OSCBinding(address: "/layer/1/position", target: .layerPosition, layerIndex: 0)]
        let message = OSCMessage(address: "/layer/1/position", arguments: [.float(0.3), .float(0.8)])
        dispatcher.dispatch(message: message, bindings: bindings)
        let pos = engine.activeScene?.layers[0].transform.position
        XCTAssertEqual(pos?.x, 0.3, accuracy: 0.001)
        XCTAssertEqual(pos?.y, 0.8, accuracy: 0.001)
    }

    func testLayerScale() {
        let (engine, dispatcher) = makeSetup()
        let bindings = [OSCBinding(address: "/layer/1/scale", target: .layerScale, layerIndex: 0)]
        let message = OSCMessage(address: "/layer/1/scale", arguments: [.float(2.0), .float(1.5)])
        dispatcher.dispatch(message: message, bindings: bindings)
        let scale = engine.activeScene?.layers[0].transform.scale
        XCTAssertEqual(scale?.x, 2.0, accuracy: 0.001)
        XCTAssertEqual(scale?.y, 1.5, accuracy: 0.001)
    }

    func testLayerRotation() {
        let (engine, dispatcher) = makeSetup()
        let bindings = [OSCBinding(address: "/layer/1/rotation", target: .layerRotation, layerIndex: 0)]
        let message = OSCMessage(address: "/layer/1/rotation", arguments: [.float(1.57)])
        dispatcher.dispatch(message: message, bindings: bindings)
        XCTAssertEqual(engine.activeScene?.layers[0].transform.rotation, 1.57, accuracy: 0.01)
    }

    func testLayerSpeed() {
        let (engine, dispatcher) = makeSetup()
        let bindings = [OSCBinding(address: "/layer/1/speed", target: .layerSpeed, layerIndex: 0)]
        let message = OSCMessage(address: "/layer/1/speed", arguments: [.float(1.25)])
        dispatcher.dispatch(message: message, bindings: bindings)
        XCTAssertEqual(engine.activeScene?.layers[0].playback.speed, 1.25, accuracy: 0.01)
    }

    func testLayerPlayState() {
        let (engine, dispatcher) = makeSetup()
        let bindings = [OSCBinding(address: "/layer/1/play", target: .layerPlayState, layerIndex: 0)]
        // Pause (0)
        let pause = OSCMessage(address: "/layer/1/play", arguments: [.float(0)])
        dispatcher.dispatch(message: pause, bindings: bindings)
        XCTAssertEqual(engine.activeScene?.layers[0].playback.state, .paused)
        // Play (1)
        let play = OSCMessage(address: "/layer/1/play", arguments: [.float(1)])
        dispatcher.dispatch(message: play, bindings: bindings)
        XCTAssertEqual(engine.activeScene?.layers[0].playback.state, .playing)
        // Stop (2)
        let stop = OSCMessage(address: "/layer/1/play", arguments: [.float(2)])
        dispatcher.dispatch(message: stop, bindings: bindings)
        XCTAssertEqual(engine.activeScene?.layers[0].playback.state, .stopped)
    }

    func testLayerLoopMode() {
        let (engine, dispatcher) = makeSetup()
        let bindings = [OSCBinding(address: "/layer/1/loop", target: .layerLoopMode, layerIndex: 0)]
        let msg = OSCMessage(address: "/layer/1/loop", arguments: [.float(1)])
        dispatcher.dispatch(message: msg, bindings: bindings)
        XCTAssertEqual(engine.activeScene?.layers[0].playback.loopMode, .loop)
    }

    // MARK: - Effect Properties

    func testLayerTintColor() {
        let (engine, dispatcher) = makeSetupWithEffects()
        let bindings = [OSCBinding(address: "/layer/1/tint/color", target: .layerTintColor, layerIndex: 0, effectIndex: 0)]
        let message = OSCMessage(address: "/layer/1/tint/color", arguments: [.float(1.0), .float(0.2), .float(0.1)])
        dispatcher.dispatch(message: message, bindings: bindings)
        if case .float3(let rgb) = engine.activeScene?.layers[0].effects[0].parameters["color"] {
            XCTAssertEqual(rgb[0], 1.0, accuracy: 0.001)
            XCTAssertEqual(rgb[1], 0.2, accuracy: 0.001)
            XCTAssertEqual(rgb[2], 0.1, accuracy: 0.001)
        } else {
            XCTFail("Expected float3 color parameter")
        }
    }

    func testLayerTintAmount() {
        let (engine, dispatcher) = makeSetupWithEffects()
        let bindings = [OSCBinding(address: "/layer/1/tint/amount", target: .layerTintAmount, layerIndex: 0, effectIndex: 0)]
        let message = OSCMessage(address: "/layer/1/tint/amount", arguments: [.float(0.8)])
        dispatcher.dispatch(message: message, bindings: bindings)
        if case .float(let amount) = engine.activeScene?.layers[0].effects[0].parameters["amount"] {
            XCTAssertEqual(amount, 0.8, accuracy: 0.001)
        } else {
            XCTFail("Expected float amount parameter")
        }
    }

    func testEffectEnabled() {
        let (engine, dispatcher) = makeSetupWithEffects()
        let bindings = [OSCBinding(address: "/layer/1/effect/0/enabled", target: .effectEnabled, layerIndex: 0, effectIndex: 0)]
        let message = OSCMessage(address: "/layer/1/effect/0/enabled", arguments: [.float(0)])
        dispatcher.dispatch(message: message, bindings: bindings)
        XCTAssertEqual(engine.activeScene?.layers[0].effects[0].enabled, false)
    }

    func testEffectParam() {
        let (engine, dispatcher) = makeSetupWithEffects()
        let bindings = [OSCBinding(address: "/layer/1/effect/0/brightness", target: .effectParam, layerIndex: 0, effectIndex: 0, parameterKey: "brightness")]
        let message = OSCMessage(address: "/layer/1/effect/0/brightness", arguments: [.float(0.3)])
        dispatcher.dispatch(message: message, bindings: bindings)
        if case .float(let value) = engine.activeScene?.layers[0].effects[0].parameters["brightness"] {
            XCTAssertEqual(value, 0.3, accuracy: 0.001)
        } else {
            XCTFail("Expected float brightness parameter")
        }
    }

    // MARK: - Binding Not Found

    func testUnboundAddressIgnored() {
        let (engine, dispatcher) = makeSetup()
        let bindings = [OSCBinding(address: "/scene/trigger", target: .sceneTrigger)]
        let message = OSCMessage(address: "/unknown/address", arguments: [.float(1.0)])
        dispatcher.dispatch(message: message, bindings: bindings)
        // No transition should have been triggered
        XCTAssertNil(engine.transitionSceneIndex)
    }

    func testMissingLayerIndexIgnored() {
        let (engine, dispatcher) = makeSetup()
        // Binding without layerIndex
        let bindings = [OSCBinding(address: "/layer/1/opacity", target: .layerOpacity)]
        let message = OSCMessage(address: "/layer/1/opacity", arguments: [.float(0.5)])
        dispatcher.dispatch(message: message, bindings: bindings)
        // Layer should remain unchanged (opacity = 1.0)
        XCTAssertEqual(engine.activeScene?.layers[0].opacity, 1.0, accuracy: 0.001)
    }

    // MARK: - Helpers

    private func makeSetup() -> (SceneEngine, OSCDispatcher) {
        let layer = LayerInstance(
            id: "l0", mediaId: "m1", order: 0,
            transform: Transform(position: Vec2(x: 0.5, y: 0.5), scale: Vec2(x: 1, y: 1), rotation: 0, anchor: Vec2(x: 0.5, y: 0.5)),
            opacity: 1.0, blendMode: .normal,
            playback: PlaybackSettings(state: .playing, loopMode: .playOnce, speed: 1.0, time: 0),
            mesh: nil, effects: []
        )
        let project = Project(
            projectName: "Test",
            media: [],
            scenes: [
                VJScene(id: "s0", name: "Scene 0", layers: [layer]),
                VJScene(id: "s1", name: "Scene 1", layers: [layer]),
                VJScene(id: "s2", name: "Scene 2", layers: [layer])
            ],
            output: OutputSettings(displayId: 0, resolution: Resolution(width: 1920, height: 1080), targetFPS: 60),
            osc: OSCSettings(port: 7000, bindings: [])
        )
        let engine = SceneEngine(project: project)
        let dispatcher = OSCDispatcher(engine: engine)
        return (engine, dispatcher)
    }

    private func makeSetupWithEffects() -> (SceneEngine, OSCDispatcher) {
        let layer = LayerInstance(
            id: "l0", mediaId: "m1", order: 0,
            transform: Transform(position: Vec2(x: 0.5, y: 0.5), scale: Vec2(x: 1, y: 1), rotation: 0, anchor: Vec2(x: 0.5, y: 0.5)),
            opacity: 1.0, blendMode: .normal,
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
        let engine = SceneEngine(project: project)
        let dispatcher = OSCDispatcher(engine: engine)
        return (engine, dispatcher)
    }
}
