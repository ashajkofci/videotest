import SwiftUI

@main
struct VJApp: App {
    @StateObject private var engine: SceneEngine
    @StateObject private var oscServer: OSCServer
    private let oscDispatcher: OSCDispatcher
    private let outputWindowController: OutputWindowController

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
        oscServer.onMessage = { message in
            oscDispatcher.dispatch(message: message, bindings: demoProject.osc.bindings)
        }
        oscServer.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine, oscServer: oscServer)
                .onAppear {
                    outputWindowController.showWindow(nil)
                }
        }
    }
}
