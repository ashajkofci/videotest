import simd

struct MeshBuilder {
    static func buildVertices(mapping: MeshMapping?, transform: Transform) -> [Vertex] {
        let columns = mapping?.columns ?? 2
        let rows = mapping?.rows ?? 2
        let points = mapping?.controlPoints ?? defaultPoints(columns: columns, rows: rows)
        var vertices: [Vertex] = []
        vertices.reserveCapacity((columns - 1) * (rows - 1) * 6)

        for row in 0..<(rows - 1) {
            for col in 0..<(columns - 1) {
                let idx = row * columns + col
                let p0 = points[idx]
                let p1 = points[idx + 1]
                let p2 = points[idx + columns]
                let p3 = points[idx + columns + 1]

                let v0 = Vertex(position: applyTransform(p0, transform), texCoord: float2(p0.x, p0.y))
                let v1 = Vertex(position: applyTransform(p1, transform), texCoord: float2(p1.x, p1.y))
                let v2 = Vertex(position: applyTransform(p2, transform), texCoord: float2(p2.x, p2.y))
                let v3 = Vertex(position: applyTransform(p3, transform), texCoord: float2(p3.x, p3.y))

                vertices.append(contentsOf: [v0, v1, v2, v2, v1, v3])
            }
        }

        return vertices
    }

    private static func defaultPoints(columns: Int, rows: Int) -> [Vec2] {
        var points: [Vec2] = []
        for row in 0..<rows {
            for col in 0..<columns {
                let x = Float(col) / Float(columns - 1)
                let y = Float(row) / Float(rows - 1)
                points.append(Vec2(x: x, y: y))
            }
        }
        return points
    }

    private static func applyTransform(_ point: Vec2, _ transform: Transform) -> float2 {
        let centered = float2(point.x - transform.anchor.x, point.y - transform.anchor.y)
        let scaled = centered * float2(transform.scale.x, transform.scale.y)
        let rotation = transform.rotation
        let rotated = float2(
            scaled.x * cos(rotation) - scaled.y * sin(rotation),
            scaled.x * sin(rotation) + scaled.y * cos(rotation)
        )
        let translated = rotated + float2(transform.position.x, transform.position.y)
        return translated
    }
}
