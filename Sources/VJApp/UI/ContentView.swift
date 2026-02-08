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
                MetalViewRepresentable()
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
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        _ = MetalRenderer(mtkView: view)
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
    }
}
