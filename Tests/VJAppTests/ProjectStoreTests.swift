import XCTest
@testable import VJApp

final class ProjectStoreTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        let store = ProjectStore()
        let project = sampleProject()
        let fileURL = tempDir.appendingPathComponent("project.json")
        try store.save(project, to: fileURL)
        let loaded = try store.load(from: fileURL)
        XCTAssertEqual(loaded.projectName, project.projectName)
        XCTAssertEqual(loaded.schemaVersion, 1)
        XCTAssertEqual(loaded.scenes.count, project.scenes.count)
        XCTAssertEqual(loaded.media.count, project.media.count)
    }

    func testSaveCreatesFile() throws {
        let store = ProjectStore()
        let fileURL = tempDir.appendingPathComponent("new_project.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        try store.save(sampleProject(), to: fileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testLoadInvalidPathThrows() {
        let store = ProjectStore()
        let badURL = tempDir.appendingPathComponent("nonexistent.json")
        XCTAssertThrowsError(try store.load(from: badURL))
    }

    func testLoadCorruptedDataThrows() throws {
        let store = ProjectStore()
        let fileURL = tempDir.appendingPathComponent("corrupt.json")
        try "not valid json{{{".data(using: .utf8)!.write(to: fileURL)
        XCTAssertThrowsError(try store.load(from: fileURL))
    }

    func testRelinkMedia() {
        let store = ProjectStore()
        let item = MediaItem(
            id: "m1", name: "clip.mp4", path: "/old/clip.mp4", resolvedPath: nil,
            duration: 30, fps: 30, resolution: Resolution(width: 1920, height: 1080),
            lastKnownBookmark: nil
        )
        let newURL = URL(fileURLWithPath: "/new/clip.mp4")
        let relinked = store.relink(media: item, newURL: newURL)
        XCTAssertEqual(relinked.resolvedPath, "/new/clip.mp4")
        XCTAssertEqual(relinked.id, item.id)
    }

    func testSavedFileIsValidJSON() throws {
        let store = ProjectStore()
        let project = sampleProject()
        let fileURL = tempDir.appendingPathComponent("valid.json")
        try store.save(project, to: fileURL)
        let data = try Data(contentsOf: fileURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }

    func testRoundTripPreservesEffects() throws {
        let store = ProjectStore()
        var project = sampleProject()
        let layer = LayerInstance(
            id: "l1", mediaId: "m1", order: 0,
            transform: Transform(position: Vec2(x: 0.5, y: 0.5), scale: Vec2(x: 1, y: 1), rotation: 0, anchor: Vec2(x: 0.5, y: 0.5)),
            opacity: 1.0, blendMode: .add,
            playback: PlaybackSettings(state: .playing, loopMode: .loop, speed: 1.0, time: 0),
            mesh: MeshMapping(columns: 3, rows: 3, controlPoints: (0..<9).map { Vec2(x: Float($0 % 3) / 2.0, y: Float($0 / 3) / 2.0) }),
            effects: [
                Effect(id: "e1", type: .tint, enabled: true, parameters: ["color": .float3([1, 0, 0]), "amount": .float(0.5)]),
                Effect(id: "e2", type: .saturation, enabled: false, parameters: ["value": .float(1.5)])
            ]
        )
        project.scenes[0].layers = [layer]
        let fileURL = tempDir.appendingPathComponent("effects.json")
        try store.save(project, to: fileURL)
        let loaded = try store.load(from: fileURL)
        let loadedLayer = loaded.scenes[0].layers[0]
        XCTAssertEqual(loadedLayer.effects.count, 2)
        XCTAssertEqual(loadedLayer.effects[0].type, .tint)
        XCTAssertEqual(loadedLayer.effects[1].type, .saturation)
        XCTAssertEqual(loadedLayer.blendMode, .add)
        XCTAssertNotNil(loadedLayer.mesh)
        XCTAssertEqual(loadedLayer.mesh?.columns, 3)
    }

    func testRoundTripPreservesOSCBindings() throws {
        let store = ProjectStore()
        var project = sampleProject()
        project.osc.bindings = [
            OSCBinding(address: "/scene/trigger", target: .sceneTrigger),
            OSCBinding(address: "/layer/1/opacity", target: .layerOpacity, layerIndex: 0),
            OSCBinding(address: "/layer/1/effect/tint/color", target: .layerTintColor, layerIndex: 0, effectIndex: 0)
        ]
        let fileURL = tempDir.appendingPathComponent("bindings.json")
        try store.save(project, to: fileURL)
        let loaded = try store.load(from: fileURL)
        XCTAssertEqual(loaded.osc.bindings.count, 3)
        XCTAssertEqual(loaded.osc.bindings[0].target, .sceneTrigger)
        XCTAssertEqual(loaded.osc.bindings[1].target, .layerOpacity)
        XCTAssertEqual(loaded.osc.bindings[1].layerIndex, 0)
        XCTAssertEqual(loaded.osc.bindings[2].target, .layerTintColor)
    }

    // MARK: - Helpers

    private func sampleProject() -> Project {
        Project(
            projectName: "Test Project",
            media: [
                MediaItem(id: "m1", name: "clip.mp4", path: "/videos/clip.mp4", resolvedPath: nil,
                          duration: 30, fps: 30, resolution: Resolution(width: 1920, height: 1080),
                          lastKnownBookmark: nil)
            ],
            scenes: [
                VJScene(id: "s1", name: "Default", layers: [
                    LayerInstance(
                        id: "l1", mediaId: "m1", order: 0,
                        transform: Transform(position: Vec2(x: 0.5, y: 0.5), scale: Vec2(x: 1, y: 1), rotation: 0, anchor: Vec2(x: 0.5, y: 0.5)),
                        opacity: 1.0, blendMode: .normal,
                        playback: PlaybackSettings(state: .playing, loopMode: .loop, speed: 1.0, time: 0),
                        mesh: nil, effects: []
                    )
                ])
            ],
            output: OutputSettings(displayId: 0, resolution: Resolution(width: 1920, height: 1080), targetFPS: 60),
            osc: OSCSettings(port: 7000, bindings: [])
        )
    }
}
