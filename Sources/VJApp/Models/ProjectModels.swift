import Foundation

struct Project: Codable {
    var schemaVersion: Int = 1
    var projectName: String
    var media: [MediaItem]
    var scenes: [Scene]
    var output: OutputSettings
    var osc: OSCSettings
}

struct MediaItem: Codable, Identifiable {
    var id: String
    var name: String
    var path: String
    var resolvedPath: String?
    var duration: Double
    var fps: Double
    var resolution: Resolution
    var lastKnownBookmark: Data?

    var isMissing: Bool {
        let activePath = resolvedPath ?? path
        return !FileManager.default.fileExists(atPath: activePath)
    }
}

struct Resolution: Codable {
    var width: Int
    var height: Int
}

struct Scene: Codable, Identifiable {
    var id: String
    var name: String
    var layers: [LayerInstance]
}

struct LayerInstance: Codable, Identifiable {
    var id: String
    var mediaId: String
    var order: Int
    var transform: Transform
    var opacity: Float
    var blendMode: BlendMode
    var playback: PlaybackSettings
    var mesh: MeshMapping?
    var effects: [Effect]
}

struct Transform: Codable {
    var position: Vec2
    var scale: Vec2
    var rotation: Float
    var anchor: Vec2
}

struct Vec2: Codable {
    var x: Float
    var y: Float
}

struct PlaybackSettings: Codable {
    var state: PlaybackState
    var loopMode: LoopMode
    var speed: Float
    var time: Double
}

enum PlaybackState: String, Codable {
    case playing
    case paused
    case stopped
}

enum LoopMode: String, Codable {
    case playOnce
    case loop
    case pingPong
}

enum BlendMode: String, Codable {
    case normal
    case add
    case multiply
    case screen
}

struct MeshMapping: Codable {
    var columns: Int
    var rows: Int
    var controlPoints: [Vec2]
}

struct Effect: Codable, Identifiable {
    var id: String
    var type: EffectType
    var enabled: Bool
    var parameters: [String: EffectParameter]
}

enum EffectType: String, Codable {
    case tint
    case brightnessContrast
    case saturation
    case hueShift
}

enum EffectParameter: Codable {
    case float(Float)
    case float3([Float])

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum ParamType: String, Codable {
        case float
        case float3
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ParamType.self, forKey: .type)
        switch type {
        case .float:
            let value = try container.decode(Float.self, forKey: .value)
            self = .float(value)
        case .float3:
            let value = try container.decode([Float].self, forKey: .value)
            self = .float3(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .float(let value):
            try container.encode(ParamType.float, forKey: .type)
            try container.encode(value, forKey: .value)
        case .float3(let value):
            try container.encode(ParamType.float3, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

struct OutputSettings: Codable {
    var displayId: Int
    var resolution: Resolution
    var targetFPS: Int
    var showStatsOverlay: Bool = true
}

struct OSCSettings: Codable {
    var port: UInt16
    var bindings: [OSCBinding]
}

struct OSCBinding: Codable, Identifiable {
    var id: String = UUID().uuidString
    var address: String
    var target: OSCTarget
    var layerIndex: Int?
    var effectIndex: Int?
    var parameterKey: String?
}

enum OSCTarget: String, Codable {
    case sceneTrigger
    case crossfadeTime
    case layerOpacity
    case layerPosition
    case layerScale
    case layerRotation
    case layerSpeed
    case layerPlayState
    case layerLoopMode
    case layerTintColor
    case layerTintAmount
    case effectEnabled
    case effectParam
}
