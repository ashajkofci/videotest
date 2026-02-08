import SwiftUI
import MetalKit
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var engine: SceneEngine
    @ObservedObject var oscServer: OSCServer
    @State private var showingVideoImporter = false
    @State private var selectedSceneIndex: Int? = nil

    var body: some View {
        HSplitView {
            // MARK: - Media Bin
            VStack(alignment: .leading) {
                HStack {
                    Text("Media Bin")
                        .font(.headline)
                    Spacer()
                    Button {
                        showingVideoImporter = true
                    } label: {
                        Label("Add Video", systemImage: "plus")
                    }
                }
                List {
                    ForEach(engine.project.media) { item in
                        HStack {
                            Image(systemName: "film")
                            Text(item.name)
                            Spacer()
                            Button(role: .destructive) {
                                engine.removeMediaItem(id: item.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingVideoImporter,
                allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: true
            ) { result in
                handleVideoImport(result)
            }

            // MARK: - Preview Canvas
            VStack {
                Text("Preview Canvas")
                    .font(.headline)
                MetalViewRepresentable(engine: engine)
            }

            // MARK: - Scenes & Layers
            VStack(alignment: .leading) {
                HStack {
                    Text("Scenes")
                        .font(.headline)
                    Spacer()
                    Button {
                        let name = "Scene \(engine.project.scenes.count)"
                        engine.addScene(name: name)
                    } label: {
                        Label("Add Scene", systemImage: "plus")
                    }
                }
                List(engine.project.scenes.indices, id: \.self) { index in
                    HStack {
                        Button(engine.project.scenes[index].name) {
                            engine.triggerScene(index: index)
                            selectedSceneIndex = index
                        }
                        Spacer()
                        Button(role: .destructive) {
                            if selectedSceneIndex == index {
                                selectedSceneIndex = nil
                            } else if let sel = selectedSceneIndex, sel > index {
                                selectedSceneIndex = sel - 1
                            }
                            engine.removeScene(id: engine.project.scenes[index].id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if let sceneIdx = selectedSceneIndex,
                   engine.project.scenes.indices.contains(sceneIdx) {
                    Divider()
                    HStack {
                        Text("Layers")
                            .font(.headline)
                        Spacer()
                        Menu {
                            ForEach(engine.project.media) { item in
                                Button(item.name) {
                                    engine.addLayer(toSceneIndex: sceneIdx, mediaId: item.id)
                                }
                            }
                        } label: {
                            Label("Add Layer", systemImage: "plus")
                        }
                        .disabled(engine.project.media.isEmpty)
                    }
                    List {
                        ForEach(engine.project.scenes[sceneIdx].layers) { layer in
                            HStack {
                                Image(systemName: "square.3.layers.3d")
                                Text(mediaName(for: layer.mediaId))
                                Spacer()
                                Button(role: .destructive) {
                                    engine.removeLayer(fromSceneIndex: sceneIdx, layerId: layer.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
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

    private func handleVideoImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            let item = MediaItem(
                id: UUID().uuidString,
                name: url.deletingPathExtension().lastPathComponent,
                path: url.path,
                resolvedPath: nil,
                duration: 0,
                fps: 30,
                resolution: Resolution(width: 1920, height: 1080),
                lastKnownBookmark: nil
            )
            engine.addMediaItem(item)
        }
    }

    private func mediaName(for mediaId: String) -> String {
        engine.project.media.first(where: { $0.id == mediaId })?.name ?? "Unknown"
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
