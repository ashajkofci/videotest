import Foundation
import Network

struct OSCMessage {
    var address: String
    var arguments: [OSCArgument]
}

enum OSCArgument {
    case int(Int32)
    case float(Float32)
    case string(String)
}

final class OSCServer: ObservableObject {
    @Published var recentMessages: [String] = []
    @Published var parseErrors: [String] = []

    private let port: UInt16
    private let queue = DispatchQueue(label: "osc.server")
    private var listener: NWListener?

    var onMessage: ((OSCMessage) -> Void)?

    init(port: UInt16) {
        self.port = port
    }

    func start() {
        do {
            let params = NWParameters.udp
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: self?.queue ?? .global())
                self?.receive(on: connection)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            appendError("OSC listener error: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let error {
                self?.appendError("OSC receive error: \(error)")
            }
            if let data, let message = OSCParser.parse(data: data) {
                DispatchQueue.main.async {
                    self?.appendMessage("\(message.address) \(message.arguments)")
                    self?.onMessage?(message)
                }
            }
            self?.receive(on: connection)
        }
    }

    private func appendMessage(_ message: String) {
        recentMessages.append(message)
        if recentMessages.count > 20 {
            recentMessages.removeFirst(recentMessages.count - 20)
        }
    }

    private func appendError(_ error: String) {
        parseErrors.append(error)
        if parseErrors.count > 20 {
            parseErrors.removeFirst(parseErrors.count - 20)
        }
    }
}

enum OSCParser {
    static func parse(data: Data) -> OSCMessage? {
        var cursor = 0
        guard let address = readString(data: data, cursor: &cursor) else { return nil }
        guard let typeTags = readString(data: data, cursor: &cursor), typeTags.first == "," else { return nil }
        var arguments: [OSCArgument] = []
        for tag in typeTags.dropFirst() {
            switch tag {
            case "i":
                guard let value = readInt32(data: data, cursor: &cursor) else { return nil }
                arguments.append(.int(value))
            case "f":
                guard let value = readFloat32(data: data, cursor: &cursor) else { return nil }
                arguments.append(.float(value))
            case "s":
                guard let value = readString(data: data, cursor: &cursor) else { return nil }
                arguments.append(.string(value))
            default:
                return nil
            }
        }
        return OSCMessage(address: address, arguments: arguments)
    }

    private static func readString(data: Data, cursor: inout Int) -> String? {
        guard cursor < data.count else { return nil }
        let start = cursor
        while cursor < data.count, data[cursor] != 0 {
            cursor += 1
        }
        guard cursor < data.count else { return nil }
        let stringData = data[start..<cursor]
        guard let result = String(data: stringData, encoding: .utf8) else { return nil }
        let aligned = align4(cursor + 1)
        guard aligned <= data.count else { return nil }
        cursor = aligned
        return result
    }

    private static func readInt32(data: Data, cursor: inout Int) -> Int32? {
        guard cursor + 4 <= data.count else { return nil }
        let value = data[cursor..<cursor + 4].withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
        cursor += 4
        return value
    }

    private static func readFloat32(data: Data, cursor: inout Int) -> Float32? {
        guard cursor + 4 <= data.count else { return nil }
        let value = data[cursor..<cursor + 4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        cursor += 4
        return Float32(bitPattern: value)
    }

    private static func align4(_ value: Int) -> Int {
        return (value + 3) & ~3
    }
}
