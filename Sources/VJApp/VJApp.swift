import SwiftUI

@main
struct VJApp: App {
    @StateObject private var engine: SceneEngine
    @StateObject private var oscServer: OSCServer
    private let oscDispatcher: OSCDispatcher
    private let outputWindowController: OutputWindowController
    private let projectStore: ProjectStore

    init() {
        let demoProject = Project(
            projectName: "New Project",
            media: [],
            scenes: [],
            output: OutputSettings(displayId: 0, resolution: Resolution(width: 1920, height: 1080), targetFPS: 60),
            osc: OSCSettings(port: 7000, bindings: [])
        )
        let engine = SceneEngine(project: demoProject)
        let oscServer = OSCServer(port: demoProject.osc.port)
        self._engine = StateObject(wrappedValue: engine)
        self._oscServer = StateObject(wrappedValue: oscServer)
        self.oscDispatcher = OSCDispatcher(engine: engine)
        self.outputWindowController = OutputWindowController(displayID: demoProject.output.displayId)
        self.projectStore = ProjectStore()
        oscServer.onMessage = { [weak engine] message in
            guard let engine else { return }
            oscDispatcher.dispatch(message: message, bindings: engine.project.osc.bindings)
        }
        oscServer.start()
        configureAutosave(for: engine)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine, oscServer: oscServer)
                .onAppear {
                    outputWindowController.showWindow(nil)
                }
        }
    }

    private func configureAutosave(for engine: SceneEngine) {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let folderURL = baseURL.appendingPathComponent("VJApp", isDirectory: true)
        let autosaveURL = folderURL.appendingPathComponent("autosave.json")
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            projectStore.startAutosave(project: { engine.project }, to: autosaveURL)
        } catch {
            NSLog("Autosave setup failed: \(error)")
        }
    }
}
