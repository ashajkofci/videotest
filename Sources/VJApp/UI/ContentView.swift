import SwiftUI
import MetalKit
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var engine: SceneEngine
    @ObservedObject var oscServer: OSCServer
    @State private var showingVideoImporter = false
    @State private var selectedSceneIndex: Int? = nil
    @State private var previewOffset: CGSize = .zero
    @State private var previewScale: CGFloat = 1.0

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
            VStack(spacing: 8) {
                Text("Preview Canvas")
                    .font(.headline)

                // General Transport Controls
                TransportBar(engine: engine)

                // Crossfade Time Slider
                HStack {
                    Text("Crossfade")
                        .font(.caption)
                    Slider(
                        value: Binding(
                            get: { engine.crossfadeTime },
                            set: { engine.setCrossfadeTime($0) }
                        ),
                        in: 0...5,
                        step: 0.1
                    )
                    Text(String(format: "%.1fs", engine.crossfadeTime))
                        .font(.caption)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.horizontal, 8)

                // Video Preview with border, drag, and resize
                VideoPreviewContainer(
                    engine: engine,
                    previewOffset: $previewOffset,
                    previewScale: $previewScale
                )

                // Preview position/scale controls
                HStack(spacing: 12) {
                    Button {
                        previewOffset = .zero
                        previewScale = 1.0
                    } label: {
                        Label("Reset View", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)

                    Spacer()

                    Text(String(format: "Zoom: %.0f%%", previewScale * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button {
                        previewScale = max(0.25, previewScale - 0.25)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)

                    Button {
                        previewScale = min(4.0, previewScale + 0.25)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)

                    Button {
                        previewScale = 1.0
                    } label: {
                        Label("Fit", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(.horizontal, 8)
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
                    SceneRow(
                        engine: engine,
                        index: index,
                        selectedSceneIndex: $selectedSceneIndex
                    )
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

// MARK: - Transport Bar

struct TransportBar: View {
    @ObservedObject var engine: SceneEngine

    var body: some View {
        HStack(spacing: 12) {
            Button { engine.restartAll() } label: {
                Image(systemName: "backward.end.fill")
            }
            .help("Restart")

            Button { engine.stopAll() } label: {
                Image(systemName: "stop.fill")
            }
            .help("Stop All")

            Button { engine.playAll() } label: {
                Image(systemName: "play.fill")
            }
            .help("Play All")

            Button { engine.pauseAll() } label: {
                Image(systemName: "pause.fill")
            }
            .help("Pause All")

            Spacer()

            if engine.activeScene != nil {
                Text("Scene: \(engine.activeScene?.name ?? "None")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if engine.transitionScene != nil {
                Text("→ \(engine.transitionScene?.name ?? "")")
                    .font(.caption)
                    .foregroundColor(.orange)
                ProgressView(value: Double(engine.crossfadeProgress))
                    .frame(width: 60)
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Scene Row with Per-Scene Transport

struct SceneRow: View {
    @ObservedObject var engine: SceneEngine
    let index: Int
    @Binding var selectedSceneIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(engine.project.scenes[index].name) {
                    engine.triggerScene(index: index)
                    selectedSceneIndex = index
                }

                if index == engine.activeSceneIndex {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.green)
                }

                Spacer()

                // Per-scene transport buttons
                Button { engine.playScene(at: index) } label: {
                    Image(systemName: "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Play Scene")

                Button { engine.pauseScene(at: index) } label: {
                    Image(systemName: "pause.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Pause Scene")

                Button { engine.stopScene(at: index) } label: {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Stop Scene")

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
    }
}

// MARK: - Video Preview Container with Border, Drag, and Resize

struct VideoPreviewContainer: View {
    @ObservedObject var engine: SceneEngine
    @Binding var previewOffset: CGSize
    @Binding var previewScale: CGFloat

    @State private var dragStartOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black

                // Video preview with drag and scale
                MetalViewRepresentable(engine: engine)
                    .aspectRatio(CGFloat(engine.project.output.resolution.width) / CGFloat(engine.project.output.resolution.height), contentMode: .fit)
                    .scaleEffect(previewScale)
                    .offset(previewOffset)
                    .border(Color.white.opacity(0.6), width: 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                previewOffset = CGSize(
                                    width: dragStartOffset.width + value.translation.width,
                                    height: dragStartOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                dragStartOffset = previewOffset
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                previewScale = max(0.25, min(4.0, value))
                            }
                    )
                    .onAppear {
                        dragStartOffset = previewOffset
                    }

                // Border overlay
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .clipped()
        }
    }
}

// MARK: - Metal View Representable

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
