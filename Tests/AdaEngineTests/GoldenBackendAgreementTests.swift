#if os(macOS) || os(Windows) || os(Linux)
import AdaRender
import Foundation
import Testing

/// Compares the checked-in Metal and WebGPU references with each other. Needs no GPU: it reads PNGs only.
///
/// The two backends rasterize and filter slightly differently, so agreement is judged with a wider tolerance than
/// a backend gets against its own references. A frame that differs more than that points at a real rendering
/// difference between the backends rather than rounding.
@Suite("Golden frame backend agreement")
struct GoldenBackendAgreementTests {
    /// Frames that are expected to differ between backends, with the reason.
    private static let expectedDifferences: [String: String] = [
        // The WebGPU encoder ignores triangle fill mode, so wireframe renders solid there.
        "pbr-spheres-wireframe": "WebGPU has no polygon fill mode",
    ]

    /// Largest per-channel step and fraction of pixels allowed to differ between backends.
    static let agreement = GoldenFrame.Tolerance(channelSteps: 12, differingFraction: 0.02)

    private static func names(in directory: String) throws -> Set<String> {
        let url = GoldenFrame.referenceURL(backend: directory, name: "x").deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        return Set(try FileManager.default.contentsOfDirectory(atPath: url.path).filter { $0.hasSuffix(".png") }.map { String($0.dropLast(4)) })
    }

    @Test func everySharedReferenceAgreesAcrossBackends() throws {
        let shared = try Self.names(in: "metal").intersection(Self.names(in: "webgpu")).subtracting(Self.expectedDifferences.keys).sorted()
        try #require(!shared.isEmpty, "Both backends must have references to compare.")
        var report: [String] = []
        for name in shared {
            let metal = try Image(contentsOf: GoldenFrame.referenceURL(backend: "metal", name: name))
            let webgpu = try Image(contentsOf: GoldenFrame.referenceURL(backend: "webgpu", name: name))
            let comparison = GoldenFrame.compare(webgpu, metal, tolerance: Self.agreement)
            report.append("\(name): \(comparison.differingPixels) px differ, largest step \(comparison.largestStep)")
            #expect(comparison.passes(Self.agreement), "\(name) differs between Metal and WebGPU: \(comparison.differingPixels) pixels, largest step \(comparison.largestStep).")
        }
        print("BACKEND-AGREEMENT\n" + report.joined(separator: "\n"))
    }

    @Test func backendsHaveTheSameReferenceNames() throws {
        let metal = try Self.names(in: "metal")
        let webgpu = try Self.names(in: "webgpu")
        // WebGPU skips the temporal path and renders wireframe solid, but every other frame exists on both.
        #expect(metal.subtracting(webgpu).isSubset(of: ["pbr-spheres-wireframe"]) || metal.subtracting(webgpu).isEmpty, "Metal-only references: \(metal.subtracting(webgpu).sorted())")
        #expect(webgpu.subtracting(metal).isEmpty, "WebGPU-only references: \(webgpu.subtracting(metal).sorted())")
    }
}
#endif
