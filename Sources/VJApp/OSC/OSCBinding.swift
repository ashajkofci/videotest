import Foundation

final class OSCDispatcher {
    private let engine: SceneEngine

    init(engine: SceneEngine) {
        self.engine = engine
    }

    func dispatch(message: OSCMessage, bindings: [OSCBinding]) {
        guard let binding = bindings.first(where: { $0.address == message.address }) else { return }
        switch binding.target {
        case .sceneTrigger:
            if let index = message.arguments.first?.intValue {
                engine.triggerScene(index: Int(index))
            } else if let name = message.arguments.first?.stringValue {
                engine.triggerScene(name: name)
            }
        case .crossfadeTime:
            if let value = message.arguments.first?.floatValue {
                engine.setCrossfadeTime(TimeInterval(value))
            }
        case .layerOpacity:
            updateLayer(binding: binding, args: message.floatArguments) { layer, args in
                if let value = args.first { layer.opacity = value }
            }
        case .layerPosition:
            updateLayer(binding: binding, args: message.floatArguments) { layer, args in
                guard args.count >= 2 else { return }
                layer.transform.position = Vec2(x: args[0], y: args[1])
            }
        case .layerScale:
            updateLayer(binding: binding, args: message.floatArguments) { layer, args in
                guard args.count >= 2 else { return }
                layer.transform.scale = Vec2(x: args[0], y: args[1])
            }
        case .layerRotation:
            updateLayer(binding: binding, args: message.floatArguments) { layer, args in
                if let value = args.first { layer.transform.rotation = value }
            }
        case .layerSpeed:
            updateLayer(binding: binding, args: message.floatArguments) { layer, args in
                if let value = args.first { layer.playback.speed = value }
            }
        case .layerPlayState:
            updateLayer(binding: binding, args: message.floatArguments) { layer, args in
                guard let value = args.first else { return }
                switch Int(value) {
                case 0: layer.playback.state = .paused
                case 1: layer.playback.state = .playing
                default: layer.playback.state = .stopped
                }
            }
        case .layerLoopMode:
            updateLayer(binding: binding, args: message.floatArguments) { layer, args in
                guard let value = args.first else { return }
                switch Int(value) {
                case 0: layer.playback.loopMode = .playOnce
                case 1: layer.playback.loopMode = .loop
                default: layer.playback.loopMode = .pingPong
                }
            }
        case .layerTintColor:
            updateEffect(binding: binding, args: message.floatArguments) { effect, args in
                guard args.count >= 3 else { return }
                effect.parameters["color"] = .float3([args[0], args[1], args[2]])
            }
        case .layerTintAmount:
            updateEffect(binding: binding, args: message.floatArguments) { effect, args in
                if let value = args.first { effect.parameters["amount"] = .float(value) }
            }
        case .effectEnabled:
            updateEffect(binding: binding, args: message.floatArguments) { effect, args in
                effect.enabled = (args.first ?? 0) > 0.5
            }
        case .effectParam:
            updateEffect(binding: binding, args: message.floatArguments) { effect, args in
                guard let key = binding.parameterKey else { return }
                if args.count == 3 {
                    effect.parameters[key] = .float3(args)
                } else if let value = args.first {
                    effect.parameters[key] = .float(value)
                }
            }
        }
    }

    private func updateLayer(binding: OSCBinding, args: [Float], _ update: @escaping (inout LayerInstance, [Float]) -> Void) {
        guard let layerIndex = binding.layerIndex else { return }
        engine.updateLayer(index: layerIndex) { layer in
            update(&layer, args)
        }
    }

    private func updateEffect(binding: OSCBinding, args: [Float], _ update: @escaping (inout Effect, [Float]) -> Void) {
        guard let layerIndex = binding.layerIndex, let effectIndex = binding.effectIndex else { return }
        engine.updateEffect(layerIndex: layerIndex, effectIndex: effectIndex) { effect in
            update(&effect, args)
        }
    }
}

private extension OSCArgument {
    var intValue: Int32? {
        if case .int(let value) = self { return value }
        return nil
    }

    var floatValue: Float32? {
        switch self {
        case .float(let value): return value
        case .int(let value): return Float32(value)
        case .string: return nil
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
}

private extension OSCMessage {
    var floatArguments: [Float] {
        arguments.compactMap { $0.floatValue }.map { Float($0) }
    }
}
