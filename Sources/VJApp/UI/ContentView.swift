import SwiftUI
import MetalKit

struct ContentView: View {
    @ObservedObject var engine: SceneEngine
    @ObservedObject var oscServer: OSCServer

    var body: some View {
        HSplitView {
            VStack(alignment: .leading) {
                Text("Media Bin")
                    .font(.headline)
                Spacer()
            }
            VStack {
                Text("Preview Canvas")
                    .font(.headline)
                MetalViewRepresentable(engine: engine)
            }
            VStack(alignment: .leading) {
                Text("Scenes")
                    .font(.headline)
                List(engine.project.scenes.indices, id: \.self) { index in
                    Button(engine.project.scenes[index].name) {
                        engine.triggerScene(index: index)
                    }
                }
                Divider()
                Text("OSC Monitor")
                    .font(.headline)
                List(oscServer.recentMessages, id: \.self) { message in
                    Text(message)
                        .font(.caption)
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 700)
    }
}

struct MetalViewRepresentable: NSViewRepresentable {
    let engine: SceneEngine

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        context.coordinator.renderer = MetalRenderer(mtkView: view)
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        renderer.activeScene = engine.activeScene
        renderer.transitionScene = engine.transitionScene
        renderer.transitionProgress = engine.crossfadeProgress
        renderer.targetFPS = engine.project.output.targetFPS
    }

    final class Coordinator {
        var renderer: MetalRenderer?
    }
}
