import Foundation
import Testing

@testable import AdaRender

@Suite("Shader module includes")
struct ShaderIncluderTests {
    private func makeModule(_ files: [String: String]) throws -> (searchPath: [ShaderSource.IncludeSearchPath], cleanup: () -> Void) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ShaderIncluderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, contents) in files {
            try contents.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        return ([._module("Test", directory)], { try? FileManager.default.removeItem(at: directory) })
    }

    @Test func singleModuleIncludeIsInlined() throws {
        let module = try makeModule(["A.glsl": "float a() { return 1.0; }\n"])
        defer { module.cleanup() }
        let result = try ShaderIncluder.processIncludes(in: "#include <Test/A.glsl>\nvoid main() {}\n", includeSearchPath: module.searchPath)
        #expect(result.contains("float a() { return 1.0; }"))
        #expect(!result.contains("#include"))
        #expect(result.contains("void main() {}"))
    }

    @Test func adjacentModuleIncludesAreInlinedSeparately() throws {
        let module = try makeModule(["A.glsl": "float a() { return 1.0; }\n", "B.glsl": "float b() { return 2.0; }\n"])
        defer { module.cleanup() }
        let source = "#include <Test/A.glsl>\n#include <Test/B.glsl>\nvoid main() {}\n"
        let result = try ShaderIncluder.processIncludes(in: source, includeSearchPath: module.searchPath)
        let first = try #require(result.range(of: "float a()"))
        let second = try #require(result.range(of: "float b()"))
        #expect(first.lowerBound < second.lowerBound, "Includes keep their source order.")
        #expect(!result.contains("#include"))
    }

    @Test func aLaterLineEndingInAnAngleBracketIsNotSwallowed() throws {
        let module = try makeModule(["A.glsl": "float a() { return 1.0; }\n"])
        defer { module.cleanup() }
        // The text after the include contains `>` at the end of a line, which a greedy name pattern would absorb.
        let source = "#include <Test/A.glsl>\nbool compare(float x) {\n    return x >\n        0.5;\n}\n"
        let result = try ShaderIncluder.processIncludes(in: source, includeSearchPath: module.searchPath)
        #expect(result.contains("float a()"))
        #expect(result.contains("return x >\n        0.5;"))
    }

    @Test func windowsLineEndingsAreAccepted() throws {
        let module = try makeModule(["A.glsl": "float a() { return 1.0; }\r\n"])
        defer { module.cleanup() }
        let result = try ShaderIncluder.processIncludes(in: "#include <Test/A.glsl>\r\nvoid main() {}\r\n", includeSearchPath: module.searchPath)
        #expect(result.contains("float a()"))
        #expect(!result.contains("#include"))
    }

    @Test func missingModuleIncludeStillThrows() throws {
        let module = try makeModule([:])
        defer { module.cleanup() }
        #expect(throws: ShaderIncluder.IncluderError.self) {
            try ShaderIncluder.processIncludes(in: "#include <Test/Missing.glsl>\n", includeSearchPath: module.searchPath)
        }
    }
}
