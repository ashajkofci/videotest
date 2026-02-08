import XCTest
@testable import VJApp

final class MeshMappingTests: XCTestCase {

    func testDefaultMeshVertices() {
        let transform = Transform(
            position: Vec2(x: 0.5, y: 0.5),
            scale: Vec2(x: 1, y: 1),
            rotation: 0,
            anchor: Vec2(x: 0.5, y: 0.5)
        )
        let vertices = MeshBuilder.buildVertices(mapping: nil, transform: transform)
        // 2x2 grid = 1 quad = 6 vertices (2 triangles)
        XCTAssertEqual(vertices.count, 6)
    }

    func testCustomMeshVertexCount() {
        let mesh = MeshMapping(
            columns: 4,
            rows: 4,
            controlPoints: (0..<16).map { Vec2(x: Float($0 % 4) / 3.0, y: Float($0 / 4) / 3.0) }
        )
        let transform = Transform(
            position: Vec2(x: 0.5, y: 0.5),
            scale: Vec2(x: 1, y: 1),
            rotation: 0,
            anchor: Vec2(x: 0.5, y: 0.5)
        )
        let vertices = MeshBuilder.buildVertices(mapping: mesh, transform: transform)
        // 4x4 grid = 3*3 quads = 9 quads * 6 vertices = 54
        XCTAssertEqual(vertices.count, 54)
    }

    func testTexCoordsMatchPoints() {
        let transform = Transform(
            position: Vec2(x: 0.0, y: 0.0),
            scale: Vec2(x: 1, y: 1),
            rotation: 0,
            anchor: Vec2(x: 0.0, y: 0.0)
        )
        let vertices = MeshBuilder.buildVertices(mapping: nil, transform: transform)
        for vertex in vertices {
            // Tex coords should be within [0,1]
            XCTAssertGreaterThanOrEqual(vertex.texCoord.x, 0)
            XCTAssertLessThanOrEqual(vertex.texCoord.x, 1)
            XCTAssertGreaterThanOrEqual(vertex.texCoord.y, 0)
            XCTAssertLessThanOrEqual(vertex.texCoord.y, 1)
        }
    }

    func testIdentityTransformPreservesPositions() {
        let transform = Transform(
            position: Vec2(x: 0.0, y: 0.0),
            scale: Vec2(x: 1, y: 1),
            rotation: 0,
            anchor: Vec2(x: 0.0, y: 0.0)
        )
        let vertices = MeshBuilder.buildVertices(mapping: nil, transform: transform)
        // With identity transform and anchor at origin, positions should equal mesh points
        for vertex in vertices {
            XCTAssertEqual(vertex.position.x, vertex.texCoord.x, accuracy: Float(0.001))
            XCTAssertEqual(vertex.position.y, vertex.texCoord.y, accuracy: Float(0.001))
        }
    }

    func test3x3MeshVertexCount() {
        let mesh = MeshMapping(
            columns: 3,
            rows: 3,
            controlPoints: (0..<9).map { Vec2(x: Float($0 % 3) / 2.0, y: Float($0 / 3) / 2.0) }
        )
        let transform = Transform(
            position: Vec2(x: 0.5, y: 0.5),
            scale: Vec2(x: 1, y: 1),
            rotation: 0,
            anchor: Vec2(x: 0.5, y: 0.5)
        )
        let vertices = MeshBuilder.buildVertices(mapping: mesh, transform: transform)
        // 3x3 grid = 2*2 quads = 4 quads * 6 vertices = 24
        XCTAssertEqual(vertices.count, 24)
    }

    func testScaleTransformAffectsPositions() {
        let transform = Transform(
            position: Vec2(x: 0.0, y: 0.0),
            scale: Vec2(x: 2.0, y: 2.0),
            rotation: 0,
            anchor: Vec2(x: 0.0, y: 0.0)
        )
        let vertices = MeshBuilder.buildVertices(mapping: nil, transform: transform)
        // Scaled by 2, so positions should be double the tex coords
        for vertex in vertices {
            XCTAssertEqual(vertex.position.x, vertex.texCoord.x * 2.0, accuracy: Float(0.001))
            XCTAssertEqual(vertex.position.y, vertex.texCoord.y * 2.0, accuracy: Float(0.001))
        }
    }
}
