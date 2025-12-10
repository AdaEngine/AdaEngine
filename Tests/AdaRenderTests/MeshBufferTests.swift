//
//  MeshBufferTests.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 10.12.2025.
//

import Testing
import AdaRender
import Math

@Suite
struct MeshBufferTests {

    // MARK: - Float Buffer Tests

    @Test func `float buffer stores and retrieves data correctly`() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let buffer = MeshBuffer<Float>(values)

        #expect(buffer.count == 5)
        #expect(buffer.elements == values)
    }

    @Test func `float buffer with indices stores data correctly`() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0]
        let indices: [UInt32] = [0, 1, 2, 2, 3, 0]
        let buffer = MeshBuffer<Float>(elements: values, indices: indices)

        #expect(buffer.count == 4)
        #expect(buffer.elements == values)
    }

    @Test func `float buffer from sequence stores data correctly`() {
        let sequence = (0..<5).map { Float($0) }
        let buffer = MeshBuffer<Float>(sequence)

        #expect(buffer.count == 5)
        #expect(buffer.elements == [0.0, 1.0, 2.0, 3.0, 4.0])
    }

    // MARK: - Integer Buffer Tests

    @Test func `int8 buffer stores and retrieves data correctly`() {
        let values: [Int8] = [1, 2, 3, -1, -128, 127]
        let buffer = MeshBuffer<Int8>(values)

        #expect(buffer.count == 6)
        #expect(buffer.elements == values)
    }

    @Test func `uint8 buffer stores and retrieves data correctly`() {
        let values: [UInt8] = [0, 1, 128, 255]
        let buffer = MeshBuffer<UInt8>(values)

        #expect(buffer.count == 4)
        #expect(buffer.elements == values)
    }

    @Test func `int16 buffer stores and retrieves data correctly`() {
        let values: [Int16] = [0, 1, -1, 32767, -32768]
        let buffer = MeshBuffer<Int16>(values)

        #expect(buffer.count == 5)
        #expect(buffer.elements == values)
    }

    @Test func `uint16 buffer stores and retrieves data correctly`() {
        let values: [UInt16] = [0, 1, 32768, 65535]
        let buffer = MeshBuffer<UInt16>(values)

        #expect(buffer.count == 4)
        #expect(buffer.elements == values)
    }

    @Test func `int32 buffer stores and retrieves data correctly`() {
        let values: [Int32] = [0, 1, -1, Int32.max, Int32.min]
        let buffer = MeshBuffer<Int32>(values)

        #expect(buffer.count == 5)
        #expect(buffer.elements == values)
    }

    @Test func `uint32 buffer stores and retrieves data correctly`() {
        let values: [UInt32] = [0, 1, UInt32.max / 2, UInt32.max]
        let buffer = MeshBuffer<UInt32>(values)

        #expect(buffer.count == 4)
        #expect(buffer.elements == values)
    }

    // MARK: - Vector Buffer Tests

    @Test func `vector2 buffer stores and retrieves data correctly`() {
        let values: [Vector2] = [
            Vector2(x: 0, y: 0),
            Vector2(x: 1, y: 2),
            Vector2(x: -1, y: -2),
            Vector2(x: 0.5, y: 0.25)
        ]
        let buffer = MeshBuffer<Vector2>(values)

        #expect(buffer.count == 4)
        #expect(buffer.elements == values)
    }

    @Test func `vector3 buffer stores and retrieves data correctly`() {
        let values: [Vector3] = [
            Vector3(x: 0, y: 0, z: 0),
            Vector3(x: 1, y: 2, z: 3),
            Vector3(x: -1, y: -2, z: -3),
            Vector3(x: 0.5, y: 0.25, z: 0.125)
        ]
        let buffer = MeshBuffer<Vector3>(values)

        #expect(buffer.count == 4)
        #expect(buffer.elements == values)
    }

    @Test func `vector4 buffer stores and retrieves data correctly`() {
        let values: [Vector4] = [
            Vector4(x: 0, y: 0, z: 0, w: 0),
            Vector4(x: 1, y: 2, z: 3, w: 4),
            Vector4(x: -1, y: -2, z: -3, w: -4),
            Vector4(x: 0.5, y: 0.25, z: 0.125, w: 0.0625)
        ]
        let buffer = MeshBuffer<Vector4>(values)

        #expect(buffer.count == 4)
        #expect(buffer.elements == values)
    }

    @Test func `vector3 buffer with indices stores data correctly`() {
        let values: [Vector3] = [
            Vector3(x: 0, y: 0, z: 0),
            Vector3(x: 1, y: 0, z: 0),
            Vector3(x: 0.5, y: 1, z: 0)
        ]
        let indices: [UInt32] = [0, 1, 2]
        let buffer = MeshBuffer<Vector3>(elements: values, indecies: indices)

        #expect(buffer.count == 3)
        #expect(buffer.elements == values)
    }

    // MARK: - Iterator Tests

    @Test func `buffer iterator returns all elements`() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let buffer = MeshBuffer<Float>(values)

        var iteratedValues: [Float] = []
        for value in buffer {
            iteratedValues.append(value)
        }

        #expect(iteratedValues == values)
    }

    @Test func `vector2 buffer iterator returns all elements`() {
        let values: [Vector2] = [
            Vector2(x: 1, y: 2),
            Vector2(x: 3, y: 4),
            Vector2(x: 5, y: 6)
        ]
        let buffer = MeshBuffer<Vector2>(values)

        var iteratedValues: [Vector2] = []
        for value in buffer {
            iteratedValues.append(value)
        }

        #expect(iteratedValues == values)
    }

    // MARK: - ForEach with Multiple Elements Tests

    @Test func `forEach with pairs iterates correctly`() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0]
        let buffer = MeshBuffer<Float>(values)

        var pairs: [(Float, Float)] = []
        buffer.forEach { a, b in
            pairs.append((a, b))
        }

        #expect(pairs.count == 2)
        #expect(pairs[0].0 == 1.0)
        #expect(pairs[0].1 == 2.0)
        #expect(pairs[1].0 == 3.0)
        #expect(pairs[1].1 == 4.0)
    }

    @Test func `forEach with triples iterates correctly`() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
        let buffer = MeshBuffer<Float>(values)

        var triples: [(Float, Float, Float)] = []
        buffer.forEach { a, b, c in
            triples.append((a, b, c))
        }

        #expect(triples.count == 2)
        #expect(triples[0] == (1.0, 2.0, 3.0))
        #expect(triples[1] == (4.0, 5.0, 6.0))
    }

    @Test func `forEach with quadruples iterates correctly`() {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        let buffer = MeshBuffer<Float>(values)

        var quadruples: [(Float, Float, Float, Float)] = []
        buffer.forEach { a, b, c, d in
            quadruples.append((a, b, c, d))
        }

        #expect(quadruples.count == 2)
        #expect(quadruples[0] == (1.0, 2.0, 3.0, 4.0))
        #expect(quadruples[1] == (5.0, 6.0, 7.0, 8.0))
    }

    // MARK: - ExpressibleByArrayLiteral Tests

    @Test func `array literal creates float buffer correctly`() {
        let buffer: MeshBuffer<Float> = [1.0, 2.0, 3.0]

        #expect(buffer.count == 3)
        #expect(buffer.elements == [1.0, 2.0, 3.0])
    }

    @Test func `array literal creates uint32 buffer correctly`() {
        let buffer: MeshBuffer<UInt32> = [0, 1, 2, 3]

        #expect(buffer.count == 4)
        #expect(buffer.elements == [0, 1, 2, 3])
    }

    @Test func `array literal creates vector3 buffer correctly`() {
        let v1 = Vector3(x: 1, y: 2, z: 3)
        let v2 = Vector3(x: 4, y: 5, z: 6)
        let buffer: MeshBuffer<Vector3> = [v1, v2]

        #expect(buffer.count == 2)
        #expect(buffer.elements == [v1, v2])
    }

    // MARK: - Equatable Tests

    @Test func `equal buffers compare correctly`() {
        let values: [Float] = [1.0, 2.0, 3.0]
        let buffer1 = MeshBuffer<Float>(values)
        let buffer2 = MeshBuffer<Float>(values)

        #expect(buffer1 == buffer2)
    }

    @Test func `different buffers compare correctly`() {
        let buffer1 = MeshBuffer<Float>([1.0, 2.0, 3.0])
        let buffer2 = MeshBuffer<Float>([1.0, 2.0, 4.0])

        #expect(buffer1 != buffer2)
    }

    @Test func `buffers with different counts are not equal`() {
        let buffer1 = MeshBuffer<Float>([1.0, 2.0, 3.0])
        let buffer2 = MeshBuffer<Float>([1.0, 2.0])

        #expect(buffer1 != buffer2)
    }

    @Test func `vector buffers compare correctly`() {
        let values: [Vector3] = [
            Vector3(x: 1, y: 2, z: 3),
            Vector3(x: 4, y: 5, z: 6)
        ]
        let buffer1 = MeshBuffer<Vector3>(values)
        let buffer2 = MeshBuffer<Vector3>(values)

        #expect(buffer1 == buffer2)
    }

    // MARK: - Edge Cases

    @Test func `single element buffer works correctly`() {
        let buffer = MeshBuffer<Float>([42.0])

        #expect(buffer.count == 1)
        #expect(buffer.elements == [42.0])
    }

    @Test func `buffer preserves element order`() {
        let values: [Float] = [5.0, 4.0, 3.0, 2.0, 1.0]
        let buffer = MeshBuffer<Float>(values)

        #expect(buffer.elements == values)
        #expect(buffer.elements[0] == 5.0)
        #expect(buffer.elements[4] == 1.0)
    }

    @Test func `buffer handles special float values`() {
        let values: [Float] = [Float.infinity, -Float.infinity, 0.0, -0.0]
        let buffer = MeshBuffer<Float>(values)

        #expect(buffer.count == 4)
        let elements = buffer.elements
        #expect(elements[0] == Float.infinity)
        #expect(elements[1] == -Float.infinity)
        #expect(elements[2] == 0.0)
        #expect(elements[3] == -0.0)
    }

    @Test func `buffer handles very small float values`() {
        let values: [Float] = [Float.leastNormalMagnitude, Float.leastNonzeroMagnitude]
        let buffer = MeshBuffer<Float>(values)

        #expect(buffer.count == 2)
        #expect(buffer.elements == values)
    }

    // MARK: - Buffer with Indices Tests

    @Test func `buffer with indices stores vertices correctly`() {
        let vertices: [Vector3] = [
            Vector3(x: 0, y: 0, z: 0),
            Vector3(x: 1, y: 0, z: 0),
            Vector3(x: 0.5, y: 1, z: 0),
            Vector3(x: 1.5, y: 1, z: 0)
        ]
        let indices: [UInt32] = [0, 1, 2, 1, 3, 2] // Two triangles sharing an edge
        let buffer = MeshBuffer<Vector3>(elements: vertices, indecies: indices)

        #expect(buffer.count == 4)
        #expect(buffer.elements == vertices)
    }

    @Test func `buffer without indices stores data correctly`() {
        let values: [Float] = [1.0, 2.0, 3.0]
        let buffer = MeshBuffer<Float>(values)

        #expect(buffer.count == 3)
        #expect(buffer.elements == values)
    }

    // MARK: - Memory Layout Tests

    @Test func `float buffer has correct memory representation`() {
        let values: [Float] = [1.0, 2.0, 3.0]
        let buffer = MeshBuffer<Float>(values)

        // Verify that the buffer count matches the input array count
        #expect(buffer.count == values.count)

        // Verify each element can be retrieved correctly
        let elements = buffer.elements
        for (index, value) in values.enumerated() {
            #expect(elements[index] == value)
        }
    }

    @Test func `vector3 buffer preserves component values`() {
        let original = Vector3(x: 1.5, y: 2.5, z: 3.5)
        let buffer = MeshBuffer<Vector3>([original])

        let retrieved = buffer.elements[0]
        #expect(retrieved.x == original.x)
        #expect(retrieved.y == original.y)
        #expect(retrieved.z == original.z)
    }

    @Test func `multiple vectors preserve all component values`() {
        let vectors: [Vector4] = [
            Vector4(x: 1, y: 2, z: 3, w: 4),
            Vector4(x: 5, y: 6, z: 7, w: 8),
            Vector4(x: 9, y: 10, z: 11, w: 12)
        ]
        let buffer = MeshBuffer<Vector4>(vectors)

        let elements = buffer.elements
        for (index, original) in vectors.enumerated() {
            #expect(elements[index].x == original.x)
            #expect(elements[index].y == original.y)
            #expect(elements[index].z == original.z)
            #expect(elements[index].w == original.w)
        }
    }
}
