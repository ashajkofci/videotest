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
            }
        case .crossfadeTime:
            if let value = message.arguments.first?.floatValue {
                engine.crossfadeTime = TimeInterval(value)
            }
        default:
            break
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
}
