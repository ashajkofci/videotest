import XCTest
@testable import VJApp

final class OSCParserTests: XCTestCase {

    // MARK: - Basic Parsing

    func testParseIntMessage() {
        let data = buildOSCMessage(address: "/scene/trigger", typeTags: ",i", args: [.int(3)])
        let message = OSCParser.parse(data: data)
        XCTAssertNotNil(message)
        XCTAssertEqual(message?.address, "/scene/trigger")
        XCTAssertEqual(message?.arguments.count, 1)
        if case .int(let value) = message?.arguments[0] {
            XCTAssertEqual(value, 3)
        } else {
            XCTFail("Expected int argument")
        }
    }

    func testParseFloatMessage() {
        let data = buildOSCMessage(address: "/layer/1/opacity", typeTags: ",f", args: [.float(0.7)])
        let message = OSCParser.parse(data: data)
        XCTAssertNotNil(message)
        XCTAssertEqual(message?.address, "/layer/1/opacity")
        if case .float(let value) = message?.arguments[0] {
            XCTAssertEqual(value, Float(0.7), accuracy: Float(0.001))
        } else {
            XCTFail("Expected float argument")
        }
    }

    func testParseStringMessage() {
        let data = buildOSCMessage(address: "/scene/trigger", typeTags: ",s", args: [.string("Intro")])
        let message = OSCParser.parse(data: data)
        XCTAssertNotNil(message)
        if case .string(let value) = message?.arguments[0] {
            XCTAssertEqual(value, "Intro")
        } else {
            XCTFail("Expected string argument")
        }
    }

    func testParseMultipleFloatArgs() {
        let data = buildOSCMessage(
            address: "/layer/1/effect/tint/color",
            typeTags: ",fff",
            args: [.float(1.0), .float(0.2), .float(0.1)]
        )
        let message = OSCParser.parse(data: data)
        XCTAssertNotNil(message)
        XCTAssertEqual(message?.arguments.count, 3)
        if case .float(let r) = message?.arguments[0],
           case .float(let g) = message?.arguments[1],
           case .float(let b) = message?.arguments[2] {
            XCTAssertEqual(r, Float(1.0), accuracy: Float(0.001))
            XCTAssertEqual(g, Float(0.2), accuracy: Float(0.001))
            XCTAssertEqual(b, Float(0.1), accuracy: Float(0.001))
        } else {
            XCTFail("Expected three float arguments")
        }
    }

    func testParseMixedArgs() {
        let data = buildOSCMessage(
            address: "/test",
            typeTags: ",ifs",
            args: [.int(42), .float(3.14), .string("hello")]
        )
        let message = OSCParser.parse(data: data)
        XCTAssertNotNil(message)
        XCTAssertEqual(message?.arguments.count, 3)
        if case .int(let i) = message?.arguments[0] { XCTAssertEqual(i, 42) }
        if case .float(let f) = message?.arguments[1] { XCTAssertEqual(f, Float(3.14), accuracy: Float(0.01)) }
        if case .string(let s) = message?.arguments[2] { XCTAssertEqual(s, "hello") }
    }

    func testParseNoArguments() {
        let data = buildOSCMessage(address: "/ping", typeTags: ",", args: [])
        let message = OSCParser.parse(data: data)
        XCTAssertNotNil(message)
        XCTAssertEqual(message?.address, "/ping")
        XCTAssertEqual(message?.arguments.count, 0)
    }

    // MARK: - Edge Cases

    func testParseEmptyDataReturnsNil() {
        let message = OSCParser.parse(data: Data())
        XCTAssertNil(message)
    }

    func testParseInvalidDataReturnsNil() {
        let message = OSCParser.parse(data: Data([0xFF, 0xFE]))
        XCTAssertNil(message)
    }

    func testParseLongAddress() {
        let addr = "/this/is/a/long/address/path"
        let data = buildOSCMessage(address: addr, typeTags: ",i", args: [.int(1)])
        let message = OSCParser.parse(data: data)
        XCTAssertEqual(message?.address, addr)
    }

    // MARK: - OSC Data Builder Helpers

    private enum OSCArg {
        case int(Int32)
        case float(Float32)
        case string(String)
    }

    private func buildOSCMessage(address: String, typeTags: String, args: [OSCArg]) -> Data {
        var data = Data()
        writeOSCString(address, to: &data)
        writeOSCString(typeTags, to: &data)
        for arg in args {
            switch arg {
            case .int(let value):
                var bigEndian = value.bigEndian
                data.append(Data(bytes: &bigEndian, count: 4))
            case .float(let value):
                var bits = value.bitPattern.bigEndian
                data.append(Data(bytes: &bits, count: 4))
            case .string(let value):
                writeOSCString(value, to: &data)
            }
        }
        return data
    }

    private func writeOSCString(_ string: String, to data: inout Data) {
        data.append(contentsOf: string.utf8)
        data.append(0)
        // Pad to 4-byte boundary
        while data.count % 4 != 0 {
            data.append(0)
        }
    }
}
