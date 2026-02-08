# VJApp MVP (macOS-first)

## Stack + architecture (macOS-first)
**Stack choice:** Swift 5.9 + SwiftUI + AVFoundation/VideoToolbox + Metal + Network framework. This keeps decoding and rendering fully GPU-accelerated on macOS 13+, uses AVFoundation for HW decode, and Metal for compositing/effects. SwiftUI provides a modern declarative UI, while MetalKit enables high-performance preview/output views.

**High-level architecture**
- **UI layer (SwiftUI/AppKit):** main window layout, inspector, scene list, layer list, preview canvas, OSC monitor.
- **Engine layer:** scene management, crossfade state, render loop orchestration, timing stats.
- **Media layer:** per-clip decoder + frame queue (CVPixelBuffer) + Metal texture upload.
- **Rendering layer:** GPU pipeline (mesh warp -> effects -> compositing -> output), Metal shaders.
- **Mapping layer:** mesh control points -> vertex buffer.
- **Control layer:** OSC server, parser, bindings -> engine commands.
- **Data layer:** project serialization (JSON schemaVersion=1) + media relink + autosave.

## MVP milestones
1. Media import + media bin + thumbnails.
2. Decoder + frame queue + Metal texture upload.
3. Render loop + GPU compositing + blend modes.
4. Per-layer transforms + on-canvas handles.
5. Scenes + crossfade.
6. Project save/load + autosave + relink flow.
7. Output window + display selection.
8. Effect stack + basic effects (tint, brightness/contrast, saturation).
9. Mesh mapping grid.
10. OSC control + bindings + monitor.

## Module structure
```
Sources/VJApp/
  VJApp.swift
  Models/
    ProjectModels.swift
  Media/
    VideoDecoder.swift
    FrameQueue.swift
  Rendering/
    MetalRenderer.swift
    ShaderTypes.swift
    MeshMapping.swift
    EffectStack.swift
  Engine/
    SceneEngine.swift
  Data/
    ProjectStore.swift
  OSC/
    OSCServer.swift
    OSCBinding.swift
  UI/
    ContentView.swift
    OutputWindowController.swift
  Resources/
    Shaders.metal
```

## Data models (schemaVersion=1)
See `Sources/VJApp/Models/ProjectModels.swift` for Codable structures used by project save/load.

### Example project.json
```json
{
  "schemaVersion": 1,
  "projectName": "Demo Set",
  "media": [
    {
      "id": "clip-a",
      "name": "City",
      "path": "/Volumes/Media/city.mp4",
      "duration": 12.5,
      "fps": 29.97,
      "resolution": {"width": 1920, "height": 1080}
    },
    {
      "id": "clip-b",
      "name": "Clouds",
      "path": "/Volumes/Media/clouds.mp4",
      "duration": 18.0,
      "fps": 60.0,
      "resolution": {"width": 1920, "height": 1080}
    }
  ],
  "scenes": [
    {
      "id": "scene-1",
      "name": "Intro",
      "layers": [
        {
          "id": "layer-1",
          "mediaId": "clip-a",
          "order": 0,
          "transform": {"position": {"x": -0.2, "y": 0.1}, "scale": {"x": 1.1, "y": 1.1}, "rotation": 0.0, "anchor": {"x": 0.5, "y": 0.5}},
          "opacity": 0.9,
          "blendMode": "screen",
          "playback": {"state": "playing", "loopMode": "loop", "speed": 1.0, "time": 0.0},
          "mesh": {
            "columns": 4,
            "rows": 4,
            "controlPoints": [
              {"x": 0.0, "y": 0.0}, {"x": 0.33, "y": 0.0}, {"x": 0.66, "y": 0.0}, {"x": 1.0, "y": 0.0},
              {"x": 0.0, "y": 0.33}, {"x": 0.33, "y": 0.33}, {"x": 0.66, "y": 0.33}, {"x": 1.0, "y": 0.33},
              {"x": 0.0, "y": 0.66}, {"x": 0.33, "y": 0.66}, {"x": 0.66, "y": 0.66}, {"x": 1.0, "y": 0.66},
              {"x": 0.0, "y": 1.0}, {"x": 0.33, "y": 1.0}, {"x": 0.66, "y": 1.0}, {"x": 1.0, "y": 1.0}
            ]
          },
          "effects": [
            {"id": "fx-1", "type": "tint", "enabled": true, "parameters": {"color": [1.0, 0.2, 0.1], "amount": 0.8}},
            {"id": "fx-2", "type": "saturation", "enabled": true, "parameters": {"amount": 1.2}}
          ]
        }
      ]
    },
    {
      "id": "scene-2",
      "name": "Wide",
      "layers": [
        {
          "id": "layer-2",
          "mediaId": "clip-b",
          "order": 0,
          "transform": {"position": {"x": 0.2, "y": -0.1}, "scale": {"x": 0.9, "y": 0.9}, "rotation": 0.1, "anchor": {"x": 0.5, "y": 0.5}},
          "opacity": 1.0,
          "blendMode": "normal",
          "playback": {"state": "paused", "loopMode": "playOnce", "speed": 1.0, "time": 3.4},
          "mesh": null,
          "effects": []
        }
      ]
    }
  ],
  "output": {"displayId": 0, "resolution": {"width": 1920, "height": 1080}, "targetFPS": 60},
  "osc": {"port": 7000, "bindings": [
    {"address": "/scene/trigger", "target": "sceneTrigger"},
    {"address": "/layer/1/opacity", "target": "layerOpacity", "layerIndex": 0},
    {"address": "/layer/1/effect/tint/color", "target": "layerTintColor", "layerIndex": 0}
  ]}
}
```

## Rendering + effects pipeline
1. Decode frames (CVPixelBuffer) -> upload to Metal texture via CVMetalTextureCache.
2. Build mesh vertices from grid control points and per-layer transform.
3. Render per-layer into offscreen texture, applying effect stack.
4. Composite layers into output using blend modes + opacity.
5. Crossfade by blending scene A/B outputs.

Effect stack implementation uses a lightweight multi-pass pipeline for simplicity (single-pass could be added later). Each effect is a Metal fragment function that reads from a texture and writes to a new render target.

## Timing strategy
- Render loop: **CVDisplayLink** on a dedicated render thread (target 60 FPS).
- Decode: per-clip queue on background thread, feed a bounded frame queue (backpressure).
- Upload: Metal command queue on render thread, avoid main thread.
- Frame policy: drop late frames; repeat last if queue empty.
- Under load: reduce preview resolution, maintain output frame pacing.

## OSC subsystem
- UDP socket using Network framework (`NWConnection` / `NWListener`).
- Minimal OSC parser (address + typetags + int/float/string).
- Bindings map address -> action; dispatch on main queue.

**Examples**
- `/scene/trigger 3`
- `/layer/1/opacity 0.7`
- `/layer/2/speed 1.25`
- `/layer/1/effect/tint/color 1.0 0.2 0.1`
- `/layer/1/effect/tint/amount 0.8`

## UI layout
- **Main window:** media bin, scene list, layer stack, preview canvas, inspector, OSC monitor.
- **Output window:** fullscreen-capable view on selected display with FPS overlay toggle.

## Test plan
- Project JSON round-trip.
- Scene activation determinism (hash layer states).
- OSC binding resolution.
- FPS + dropped frames counter sanity checks.

## TODO
- Advanced mesh UI (bezier/curved).
- Global output effect stack.
- Multi-output.
- MIDI/OSC learn.
