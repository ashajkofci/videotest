import SwiftUI
import MetalKit
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var engine: SceneEngine
    @ObservedObject var oscServer: OSCServer
    @State private var showingVideoImporter = false
    @State private var selectedSceneIndex: Int? = nil
    @State private var selectedLayerId: String? = nil
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

                // Timeline Bar
                TimelineBar(engine: engine)

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
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
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
                    .padding(.horizontal, 8)

                    ForEach(engine.project.scenes.indices, id: \.self) { index in
                        SceneRow(
                            engine: engine,
                            index: index,
                            selectedSceneIndex: $selectedSceneIndex
                        )
                        .padding(.horizontal, 8)
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
                        .padding(.horizontal, 8)

                        ForEach(engine.project.scenes[sceneIdx].layers) { layer in
                            LayerRow(
                                engine: engine,
                                sceneIndex: sceneIdx,
                                layer: layer,
                                selectedLayerId: $selectedLayerId,
                                mediaName: mediaName(for: layer.mediaId)
                            )
                            .padding(.horizontal, 8)
                        }

                        // Layer Detail Panel
                        if let layerId = selectedLayerId,
                           let layerIndex = engine.project.scenes[sceneIdx].layers.firstIndex(where: { $0.id == layerId }) {
                            Divider()
                            LayerDetailPanel(
                                engine: engine,
                                sceneIndex: sceneIdx,
                                layerIndex: layerIndex
                            )
                            .padding(.horizontal, 8)
                        }
                    }

                    Divider()
                    Text("OSC Monitor")
                        .font(.headline)
                        .padding(.horizontal, 8)
                    ForEach(oscServer.recentMessages, id: \.self) { message in
                        Text(message)
                            .font(.caption)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 8)
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
            engine.ensureDecoder(for: item)
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

            if let scene = engine.activeScene {
                Text("Scene: \(scene.name)")
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

// MARK: - Timeline Bar

struct TimelineBar: View {
    @ObservedObject var engine: SceneEngine

    private var hasDuration: Bool {
        engine.currentDuration > 0 && engine.currentDuration.isFinite
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(hasDuration ? formatTime(engine.currentPlaybackTime) : "--:--")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)

                Slider(
                    value: Binding(
                        get: { engine.currentPlaybackTime },
                        set: { engine.seekActiveSceneLayers(to: $0) }
                    ),
                    in: 0...max(engine.currentDuration, 0.01)
                )
                .disabled(!hasDuration)

                Text(hasDuration ? formatTime(engine.currentDuration) : "--:--")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Scene Row with Per-Scene Transport and Transition Button

struct SceneRow: View {
    @ObservedObject var engine: SceneEngine
    let index: Int
    @Binding var selectedSceneIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(engine.project.scenes[index].name) {
                    selectedSceneIndex = index
                }

                if index == engine.activeSceneIndex {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.green)
                }

                Spacer()

                // Transition button - crossfade to this scene
                if index != engine.activeSceneIndex {
                    Button {
                        engine.triggerScene(index: index)
                    } label: {
                        Label("Transition", systemImage: "arrow.right.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Crossfade to this scene")
                }

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

// MARK: - Layer Row

struct LayerRow: View {
    @ObservedObject var engine: SceneEngine
    let sceneIndex: Int
    let layer: LayerInstance
    @Binding var selectedLayerId: String?
    let mediaName: String

    var body: some View {
        HStack {
            Image(systemName: "square.3.layers.3d")
            Button {
                selectedLayerId = (selectedLayerId == layer.id) ? nil : layer.id
            } label: {
                Text(mediaName)
                    .foregroundColor(selectedLayerId == layer.id ? .accentColor : .primary)
            }
            .buttonStyle(.borderless)
            Spacer()
            Button(role: .destructive) {
                if selectedLayerId == layer.id {
                    selectedLayerId = nil
                }
                engine.removeLayer(fromSceneIndex: sceneIndex, layerId: layer.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
        .background(selectedLayerId == layer.id ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Layer Detail Panel (Transform, Effects)

struct LayerDetailPanel: View {
    @ObservedObject var engine: SceneEngine
    let sceneIndex: Int
    let layerIndex: Int

    private var layer: LayerInstance {
        engine.project.scenes[sceneIndex].layers[layerIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Layer Properties")
                .font(.headline)

            // Position
            Group {
                Text("Position").font(.caption).foregroundColor(.secondary)
                HStack {
                    Text("X").font(.caption2).frame(width: 14)
                    Slider(
                        value: Binding(
                            get: { Double(layer.transform.position.x) },
                            set: { engine.updateLayer(sceneIndex: sceneIndex, layerIndex: layerIndex) { l in l.transform.position.x = Float($0) } }
                        ),
                        in: -1...2
                    )
                    Text(String(format: "%.2f", layer.transform.position.x))
                        .font(.caption2.monospacedDigit())
                        .frame(width: 40, alignment: .trailing)
                }
                HStack {
                    Text("Y").font(.caption2).frame(width: 14)
                    Slider(
                        value: Binding(
                            get: { Double(layer.transform.position.y) },
                            set: { engine.updateLayer(sceneIndex: sceneIndex, layerIndex: layerIndex) { l in l.transform.position.y = Float($0) } }
                        ),
                        in: -1...2
                    )
                    Text(String(format: "%.2f", layer.transform.position.y))
                        .font(.caption2.monospacedDigit())
                        .frame(width: 40, alignment: .trailing)
                }
            }

            // Scale
            Group {
                Text("Scale").font(.caption).foregroundColor(.secondary)
                HStack {
                    Text("W").font(.caption2).frame(width: 14)
                    Slider(
                        value: Binding(
                            get: { Double(layer.transform.scale.x) },
                            set: { engine.updateLayer(sceneIndex: sceneIndex, layerIndex: layerIndex) { l in l.transform.scale.x = Float($0) } }
                        ),
                        in: 0.1...4.0
                    )
                    Text(String(format: "%.2f", layer.transform.scale.x))
                        .font(.caption2.monospacedDigit())
                        .frame(width: 40, alignment: .trailing)
                }
                HStack {
                    Text("H").font(.caption2).frame(width: 14)
                    Slider(
                        value: Binding(
                            get: { Double(layer.transform.scale.y) },
                            set: { engine.updateLayer(sceneIndex: sceneIndex, layerIndex: layerIndex) { l in l.transform.scale.y = Float($0) } }
                        ),
                        in: 0.1...4.0
                    )
                    Text(String(format: "%.2f", layer.transform.scale.y))
                        .font(.caption2.monospacedDigit())
                        .frame(width: 40, alignment: .trailing)
                }
            }

            // Opacity
            HStack {
                Text("Opacity").font(.caption).foregroundColor(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(layer.opacity) },
                        set: { engine.updateLayer(sceneIndex: sceneIndex, layerIndex: layerIndex) { l in l.opacity = Float($0) } }
                    ),
                    in: 0...1
                )
                Text(String(format: "%.0f%%", layer.opacity * 100))
                    .font(.caption2.monospacedDigit())
                    .frame(width: 40, alignment: .trailing)
            }

            // Rotation
            HStack {
                Text("Rotation").font(.caption).foregroundColor(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(layer.transform.rotation) },
                        set: { engine.updateLayer(sceneIndex: sceneIndex, layerIndex: layerIndex) { l in l.transform.rotation = Float($0) } }
                    ),
                    in: -Double.pi...Double.pi
                )
                Text(String(format: "%.0f°", layer.transform.rotation * 180 / .pi))
                    .font(.caption2.monospacedDigit())
                    .frame(width: 40, alignment: .trailing)
            }

            // Blend Mode
            HStack {
                Text("Blend").font(.caption).foregroundColor(.secondary)
                Picker("", selection: Binding(
                    get: { layer.blendMode },
                    set: { mode in engine.updateLayer(sceneIndex: sceneIndex, layerIndex: layerIndex) { l in l.blendMode = mode } }
                )) {
                    Text("Normal").tag(BlendMode.normal)
                    Text("Add").tag(BlendMode.add)
                    Text("Multiply").tag(BlendMode.multiply)
                    Text("Screen").tag(BlendMode.screen)
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Effects Section
            HStack {
                Text("Effects")
                    .font(.subheadline).bold()
                Spacer()
                Menu {
                    Button("Tint") { engine.addEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, type: .tint) }
                    Button("Brightness / Contrast") { engine.addEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, type: .brightnessContrast) }
                    Button("Saturation") { engine.addEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, type: .saturation) }
                    Button("Hue Shift") { engine.addEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, type: .hueShift) }
                } label: {
                    Label("Add Effect", systemImage: "plus.circle")
                        .font(.caption)
                }
            }

            ForEach(layer.effects) { effect in
                EffectRow(engine: engine, sceneIndex: sceneIndex, layerIndex: layerIndex, effect: effect)
            }
        }
    }
}

// MARK: - Effect Row with Parameters

struct EffectRow: View {
    @ObservedObject var engine: SceneEngine
    let sceneIndex: Int
    let layerIndex: Int
    let effect: Effect

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle(isOn: Binding(
                    get: { effect.enabled },
                    set: { enabled in
                        engine.updateEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, effectId: effect.id) { e in e.enabled = enabled }
                    }
                )) {
                    Text(effectTypeName(effect.type))
                        .font(.caption).bold()
                }
                .toggleStyle(.checkbox)

                Spacer()

                Button(role: .destructive) {
                    engine.removeEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, effectId: effect.id)
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            if effect.enabled {
                effectParameterControls
            }
        }
        .padding(6)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }

    @ViewBuilder
    private var effectParameterControls: some View {
        switch effect.type {
        case .tint:
            tintControls
        case .brightnessContrast:
            brightnessContrastControls
        case .saturation:
            saturationControls
        case .hueShift:
            hueShiftControls
        }
    }

    private var tintControls: some View {
        VStack(spacing: 2) {
            let color = effect.parameters["color"]?.float3Value ?? [1, 1, 1]
            let amount = effect.parameters["amount"]?.floatValue ?? 0

            HStack {
                Text("R").font(.caption2).frame(width: 14)
                Slider(
                    value: Binding(
                        get: { Double(color[0]) },
                        set: { val in
                            var c = color; c[0] = Float(val)
                            engine.updateEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, effectId: effect.id) { e in e.parameters["color"] = .float3(c) }
                        }
                    ),
                    in: 0...1
                )
                .tint(.red)
            }
            HStack {
                Text("G").font(.caption2).frame(width: 14)
                Slider(
                    value: Binding(
                        get: { Double(color[1]) },
                        set: { val in
                            var c = color; c[1] = Float(val)
                            engine.updateEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, effectId: effect.id) { e in e.parameters["color"] = .float3(c) }
                        }
                    ),
                    in: 0...1
                )
                .tint(.green)
            }
            HStack {
                Text("B").font(.caption2).frame(width: 14)
                Slider(
                    value: Binding(
                        get: { Double(color[2]) },
                        set: { val in
                            var c = color; c[2] = Float(val)
                            engine.updateEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, effectId: effect.id) { e in e.parameters["color"] = .float3(c) }
                        }
                    ),
                    in: 0...1
                )
                .tint(.blue)
            }
            HStack {
                Text("Amount").font(.caption2)
                Slider(
                    value: Binding(
                        get: { Double(amount) },
                        set: { engine.updateEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, effectId: effect.id) { e in e.parameters["amount"] = .float(Float($0)) } }
                    ),
                    in: 0...1
                )
                Text(String(format: "%.0f%%", amount * 100))
                    .font(.caption2.monospacedDigit())
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }

    private var brightnessContrastControls: some View {
        VStack(spacing: 2) {
            let brightness = effect.parameters["brightness"]?.floatValue ?? 0
            let contrast = effect.parameters["contrast"]?.floatValue ?? 1

            HStack {
                Text("Brightness").font(.caption2)
                Slider(
                    value: Binding(
                        get: { Double(brightness) },
                        set: { engine.updateEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, effectId: effect.id) { e in e.parameters["brightness"] = .float(Float($0)) } }
                    ),
                    in: -1...1
                )
                Text(String(format: "%.2f", brightness))
                    .font(.caption2.monospacedDigit())
                    .frame(width: 36, alignment: .trailing)
            }
            HStack {
                Text("Contrast").font(.caption2)
                Slider(
                    value: Binding(
                        get: { Double(contrast) },
                        set: { engine.updateEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, effectId: effect.id) { e in e.parameters["contrast"] = .float(Float($0)) } }
                    ),
                    in: 0...3
                )
                Text(String(format: "%.2f", contrast))
                    .font(.caption2.monospacedDigit())
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }

    private var saturationControls: some View {
        let saturation = effect.parameters["saturation"]?.floatValue ?? 1
        return HStack {
            Text("Saturation").font(.caption2)
            Slider(
                value: Binding(
                    get: { Double(saturation) },
                    set: { engine.updateEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, effectId: effect.id) { e in e.parameters["saturation"] = .float(Float($0)) } }
                ),
                in: 0...3
            )
            Text(String(format: "%.2f", saturation))
                .font(.caption2.monospacedDigit())
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var hueShiftControls: some View {
        let hueShift = effect.parameters["hueShift"]?.floatValue ?? 0
        return HStack {
            Text("Hue Shift").font(.caption2)
            Slider(
                value: Binding(
                    get: { Double(hueShift) },
                    set: { engine.updateEffect(sceneIndex: sceneIndex, layerIndex: layerIndex, effectId: effect.id) { e in e.parameters["hueShift"] = .float(Float($0)) } }
                ),
                in: -Double.pi...Double.pi
            )
            Text(String(format: "%.0f°", hueShift * 180 / .pi))
                .font(.caption2.monospacedDigit())
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func effectTypeName(_ type: EffectType) -> String {
        switch type {
        case .tint: return "Tint"
        case .brightnessContrast: return "Brightness / Contrast"
        case .saturation: return "Saturation"
        case .hueShift: return "Hue Shift"
        }
    }
}

// MARK: - Video Preview Container with Border, Drag, and Resize

struct VideoPreviewContainer: View {
    @ObservedObject var engine: SceneEngine
    @Binding var previewOffset: CGSize
    @Binding var previewScale: CGFloat

    @State private var dragStartOffset: CGSize = .zero
    @State private var scaleAtGestureStart: CGFloat = 1.0

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
                                previewScale = max(0.25, min(4.0, scaleAtGestureStart * value))
                            }
                            .onEnded { _ in
                                scaleAtGestureStart = previewScale
                            }
                    )
                    .onAppear {
                        dragStartOffset = previewOffset
                        scaleAtGestureStart = previewScale
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

        // Convert latest pixel buffers to Metal textures for the renderer
        var textures: [String: MTLTexture] = [:]
        for (mediaId, pixelBuffer) in engine.latestPixelBuffers {
            if let texture = renderer.texture(from: pixelBuffer) {
                textures[mediaId] = texture
            }
        }
        renderer.layerTextures = textures
    }

    final class Coordinator {
        var renderer: MetalRenderer?
    }
}

// MARK: - EffectParameter Helpers

extension EffectParameter {
    var floatValue: Float? {
        if case .float(let v) = self { return v }
        return nil
    }

    var float3Value: [Float]? {
        if case .float3(let v) = self { return v }
        return nil
    }
}
