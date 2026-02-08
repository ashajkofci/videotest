import XCTest
@testable import VJApp

final class ProjectModelsTests: XCTestCase {

    // MARK: - Round-trip Serialization

    func testProjectRoundTrip() throws {
        let project = Self.sampleProject()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, project.schemaVersion)
        XCTAssertEqual(decoded.projectName, project.projectName)
        XCTAssertEqual(decoded.media.count, project.media.count)
        XCTAssertEqual(decoded.scenes.count, project.scenes.count)
        XCTAssertEqual(decoded.output.targetFPS, project.output.targetFPS)
        XCTAssertEqual(decoded.osc.port, project.osc.port)
    }

    func testMediaItemRoundTrip() throws {
        let item = MediaItem(
            id: "m1",
            name: "test.mp4",
            path: "/videos/test.mp4",
            resolvedPath: nil,
            duration: 120.5,
            fps: 29.97,
            resolution: Resolution(width: 1920, height: 1080),
            lastKnownBookmark: nil
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(MediaItem.self, from: data)
        XCTAssertEqual(decoded.id, item.id)
        XCTAssertEqual(decoded.name, item.name)
        XCTAssertEqual(decoded.path, item.path)
        XCTAssertEqual(decoded.duration, item.duration, accuracy: 0.001)
        XCTAssertEqual(decoded.fps, item.fps, accuracy: 0.001)
        XCTAssertEqual(decoded.resolution.width, 1920)
        XCTAssertEqual(decoded.resolution.height, 1080)
    }

    func testSceneRoundTrip() throws {
        let scene = Self.sampleScene(name: "Scene A")
        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(VJScene.self, from: data)
        XCTAssertEqual(decoded.name, "Scene A")
        XCTAssertEqual(decoded.layers.count, scene.layers.count)
    }

    func testLayerInstanceRoundTrip() throws {
        let layer = Self.sampleLayer(mediaId: "m1")
        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(LayerInstance.self, from: data)
        XCTAssertEqual(decoded.mediaId, "m1")
        XCTAssertEqual(decoded.opacity, layer.opacity)
        XCTAssertEqual(decoded.transform.position.x, layer.transform.position.x)
        XCTAssertEqual(decoded.transform.scale.y, layer.transform.scale.y)
    }

    func testEffectParameterRoundTrip() throws {
        let floatParam = EffectParameter.float(0.75)
        let float3Param = EffectParameter.float3([1.0, 0.5, 0.2])

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let floatData = try encoder.encode(floatParam)
        let decodedFloat = try decoder.decode(EffectParameter.self, from: floatData)
        if case .float(let value) = decodedFloat {
            XCTAssertEqual(value, 0.75, accuracy: 0.001)
        } else {
            XCTFail("Expected .float parameter")
        }

        let float3Data = try encoder.encode(float3Param)
        let decodedFloat3 = try decoder.decode(EffectParameter.self, from: float3Data)
        if case .float3(let values) = decodedFloat3 {
            XCTAssertEqual(values.count, 3)
            XCTAssertEqual(values[0], 1.0, accuracy: 0.001)
            XCTAssertEqual(values[1], 0.5, accuracy: 0.001)
            XCTAssertEqual(values[2], 0.2, accuracy: 0.001)
        } else {
            XCTFail("Expected .float3 parameter")
        }
    }

    func testEffectRoundTrip() throws {
        let effect = Effect(
            id: "e1",
            type: .tint,
            enabled: true,
            parameters: [
                "color": .float3([1.0, 0.0, 0.0]),
                "amount": .float(0.5)
            ]
        )
        let data = try JSONEncoder().encode(effect)
        let decoded = try JSONDecoder().decode(Effect.self, from: data)
        XCTAssertEqual(decoded.id, "e1")
        XCTAssertEqual(decoded.type, .tint)
        XCTAssertTrue(decoded.enabled)
        XCTAssertNotNil(decoded.parameters["color"])
        XCTAssertNotNil(decoded.parameters["amount"])
    }

    func testMeshMappingRoundTrip() throws {
        let mesh = MeshMapping(
            columns: 4,
            rows: 4,
            controlPoints: (0..<16).map { Vec2(x: Float($0 % 4) / 3.0, y: Float($0 / 4) / 3.0) }
        )
        let data = try JSONEncoder().encode(mesh)
        let decoded = try JSONDecoder().decode(MeshMapping.self, from: data)
        XCTAssertEqual(decoded.columns, 4)
        XCTAssertEqual(decoded.rows, 4)
        XCTAssertEqual(decoded.controlPoints.count, 16)
    }

    func testOSCBindingRoundTrip() throws {
        let binding = OSCBinding(
            address: "/layer/1/opacity",
            target: .layerOpacity,
            layerIndex: 0
        )
        let data = try JSONEncoder().encode(binding)
        let decoded = try JSONDecoder().decode(OSCBinding.self, from: data)
        XCTAssertEqual(decoded.address, "/layer/1/opacity")
        XCTAssertEqual(decoded.target, .layerOpacity)
        XCTAssertEqual(decoded.layerIndex, 0)
    }

    func testSchemaVersionPreserved() throws {
        var project = Self.sampleProject()
        project.schemaVersion = 1
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    func testBlendModeRoundTrip() throws {
        let modes: [BlendMode] = [.normal, .add, .multiply, .screen]
        for mode in modes {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(BlendMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    func testPlaybackStateRoundTrip() throws {
        let states: [PlaybackState] = [.playing, .paused, .stopped]
        for state in states {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(PlaybackState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    func testLoopModeRoundTrip() throws {
        let modes: [LoopMode] = [.playOnce, .loop, .pingPong]
        for mode in modes {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(LoopMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    func testEffectTypeRoundTrip() throws {
        let types: [EffectType] = [.tint, .brightnessContrast, .saturation, .hueShift]
        for type in types {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(EffectType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    func testProjectWithMultipleScenesAndLayers() throws {
        let project = Project(
            projectName: "Multi Scene Project",
            media: [
                MediaItem(id: "m1", name: "a.mp4", path: "/a.mp4", resolvedPath: nil,
                          duration: 60, fps: 30, resolution: Resolution(width: 1920, height: 1080), lastKnownBookmark: nil),
                MediaItem(id: "m2", name: "b.mp4", path: "/b.mp4", resolvedPath: nil,
                          duration: 30, fps: 60, resolution: Resolution(width: 3840, height: 2160), lastKnownBookmark: nil)
            ],
            scenes: [
                VJScene(id: "s1", name: "Intro", layers: [
                    Self.sampleLayer(mediaId: "m1"),
                    Self.sampleLayer(mediaId: "m2")
                ]),
                VJScene(id: "s2", name: "Main", layers: [
                    Self.sampleLayer(mediaId: "m2")
                ])
            ],
            output: OutputSettings(displayId: 0, resolution: Resolution(width: 1920, height: 1080), targetFPS: 60),
            osc: OSCSettings(port: 7000, bindings: [
                OSCBinding(address: "/scene/trigger", target: .sceneTrigger),
                OSCBinding(address: "/layer/1/opacity", target: .layerOpacity, layerIndex: 0)
            ])
        )

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        XCTAssertEqual(decoded.scenes.count, 2)
        XCTAssertEqual(decoded.scenes[0].layers.count, 2)
        XCTAssertEqual(decoded.scenes[1].layers.count, 1)
        XCTAssertEqual(decoded.media.count, 2)
        XCTAssertEqual(decoded.osc.bindings.count, 2)
    }

    // MARK: - Helpers

    static func sampleProject() -> Project {
        Project(
            projectName: "Test Project",
            media: [
                MediaItem(id: "m1", name: "clip.mp4", path: "/videos/clip.mp4", resolvedPath: nil,
                          duration: 30.0, fps: 30.0, resolution: Resolution(width: 1920, height: 1080),
                          lastKnownBookmark: nil)
            ],
            scenes: [sampleScene(name: "Scene 1")],
            output: OutputSettings(displayId: 0, resolution: Resolution(width: 1920, height: 1080), targetFPS: 60),
            osc: OSCSettings(port: 7000, bindings: [])
        )
    }

    static func sampleScene(name: String) -> VJScene {
        VJScene(
            id: UUID().uuidString,
            name: name,
            layers: [sampleLayer(mediaId: "m1")]
        )
    }

    static func sampleLayer(mediaId: String) -> LayerInstance {
        LayerInstance(
            id: UUID().uuidString,
            mediaId: mediaId,
            order: 0,
            transform: Transform(
                position: Vec2(x: 0.5, y: 0.5),
                scale: Vec2(x: 1.0, y: 1.0),
                rotation: 0.0,
                anchor: Vec2(x: 0.5, y: 0.5)
            ),
            opacity: 1.0,
            blendMode: .normal,
            playback: PlaybackSettings(state: .playing, loopMode: .loop, speed: 1.0, time: 0),
            mesh: nil,
            effects: []
        )
    }
}
