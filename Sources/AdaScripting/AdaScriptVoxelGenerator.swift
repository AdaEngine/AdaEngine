import AdaAssets
import Foundation
import Gravity

/// A voxel model produced by an AdaScript generator.
public struct AdaScriptVoxelResult: Sendable {
    public let model: VOXModel
    public let palette: VOXPalette
}

/// Runs an agent-authored AdaScript `build(model)` function in an isolated VM and collects the voxels it paints.
///
/// The script gets no file, network, scene or engine access. It only sees the `model` builder
/// (`size`, `palette`, `voxel`, `box`, `sphere`, `cylinder`, `colorAt`), and the same source and
/// execution-budget limits as downloaded community scripts apply. Encoding and writing the
/// `.vox` file stay with the host (see ``VOXWriter``).
@MainActor
public enum AdaScriptVoxelGenerator {
    public static func generate(source: String) throws -> AdaScriptVoxelResult {
        let bridge = AdaScriptVoxelBridge()
        try AdaScriptGeneratorRunner.run(source: source, kind: "voxel", bridge: bridge, prelude: builderPrelude, factory: "__ada_make_voxel_builder")
        if let failure = bridge.failure { throw AdaScriptError.invalidManifest(failure) }
        return try bridge.result()
    }

    // Parameter validation lives in the bridge; the script-side wrapper only forwards positional values.
    private static let builderPrelude = """

        class __AdaVoxelBuilder {
            var __host;
            func init(host) { __host = host; }
            func size(x, y, z) { return __host.setSize(x, y, z); }
            func palette(index, red, green, blue) { return __host.setPalette(index, red, green, blue); }
            func voxel(x, y, z, color) { return __host.paintVoxel(x, y, z, color); }
            func box(x0, y0, z0, x1, y1, z1, color) {
                __host.stage(x0, y0, z0);
                return __host.paintBox(x1, y1, z1, color);
            }
            func sphere(x, y, z, radius, color) {
                __host.stage(x, y, z);
                return __host.paintSphere(radius, color);
            }
            func cylinder(x, y, z0, z1, radius, color) {
                __host.stage(x, y, z0);
                return __host.paintCylinder(z1, radius, color);
            }
            func colorAt(x, y, z) { return __host.colorAt(x, y, z); }
        }
        func __ada_make_voxel_builder(host) { return __AdaVoxelBuilder(host); }
        """
}

// Only the owning main-actor generator touches this bridge, inside the shared VM lock.
@GSExportable("AdaVoxelBuilderHost")
final class AdaScriptVoxelBridge {
    @GSExportableIgnore var failure: String?
    @GSExportableIgnore private var sizeX = 0
    @GSExportableIgnore private var sizeY = 0
    @GSExportableIgnore private var sizeZ = 0
    @GSExportableIgnore private var cells: [UInt8] = []
    @GSExportableIgnore private var colors = VOXPalette.fallback.colors
    @GSExportableIgnore private var staged: (Double, Double, Double) = (0, 0, 0)

    init() {}

    @GSExportableIgnore
    func result() throws -> AdaScriptVoxelResult {
        guard !cells.isEmpty else { throw AdaScriptError.invalidManifest("The script never called model.size(x, y, z).") }
        var voxels: [VOXVoxel] = []
        for z in 0..<sizeZ {
            for y in 0..<sizeY {
                for x in 0..<sizeX {
                    let color = cells[index(x, y, z)]
                    if color != 0 { voxels.append(VOXVoxel(x: UInt8(x), y: UInt8(y), z: UInt8(z), colorIndex: color)) }
                }
            }
        }
        guard !voxels.isEmpty else { throw AdaScriptError.invalidManifest("The script painted no voxels.") }
        return AdaScriptVoxelResult(
            model: VOXModel(sizeX: sizeX, sizeY: sizeY, sizeZ: sizeZ, voxels: voxels),
            palette: VOXPalette(colors: colors)
        )
    }

    func setSize(x: GSValue, y: GSValue, z: GSValue) -> Bool {
        guard cells.isEmpty else { return fail("model.size can be called once.") }
        guard let x = integer(x), let y = integer(y), let z = integer(z), (1...256).contains(x), (1...256).contains(y), (1...256).contains(z) else {
            return fail("model.size expects three integers in 1...256.")
        }
        sizeX = x
        sizeY = y
        sizeZ = z
        cells = Array(repeating: 0, count: x * y * z)
        return true
    }

    func setPalette(index: GSValue, red: GSValue, green: GSValue, blue: GSValue) -> Bool {
        guard let index = integer(index), (1...255).contains(index), let red = integer(red), let green = integer(green), let blue = integer(blue),
            [red, green, blue].allSatisfy({ (0...255).contains($0) })
        else {
            return fail("model.palette expects an index in 1...255 and red, green and blue in 0...255.")
        }
        colors[index - 1] = VOXColor(red: UInt8(red), green: UInt8(green), blue: UInt8(blue))
        return true
    }

    func paintVoxel(x: GSValue, y: GSValue, z: GSValue, color: GSValue) -> Bool {
        guard let color = paintColor(color), let x = integer(x), let y = integer(y), let z = integer(z) else {
            return fail("model.voxel expects x, y, z integers and a color in 0...255.")
        }
        guard contains(x, y, z) else { return fail("model.voxel (\(x), \(y), \(z)) is outside the model size.") }
        cells[index(x, y, z)] = color
        return true
    }

    /// Remembers the first three numbers of a shape call; Gravity bridge methods take at most four arguments.
    func stage(a: GSValue, b: GSValue, c: GSValue) -> Bool {
        guard let a = number(a), let b = number(b), let c = number(c) else {
            return fail("Shape coordinates must be finite numbers.")
        }
        staged = (a, b, c)
        return true
    }

    func paintBox(x1: GSValue, y1: GSValue, z1: GSValue, color: GSValue) -> Bool {
        guard failure == nil, let color = paintColor(color), let x0 = whole(staged.0), let y0 = whole(staged.1), let z0 = whole(staged.2),
            let x1 = integer(x1), let y1 = integer(y1), let z1 = integer(z1)
        else {
            return fail("model.box expects six integer corners (inclusive) and a color in 0...255.")
        }
        fill(color, x: min(x0, x1)...max(x0, x1), y: min(y0, y1)...max(y0, y1), z: min(z0, z1)...max(z0, z1)) { _, _, _ in true }
        return failure == nil
    }

    func paintSphere(radius: GSValue, color: GSValue) -> Bool {
        let (cx, cy, cz) = staged
        guard failure == nil, let color = paintColor(color), let radius = number(radius), radius >= 0 else {
            return fail("model.sphere expects a center, a non-negative radius and a color in 0...255.")
        }
        fill(color, x: bounds(cx, radius), y: bounds(cy, radius), z: bounds(cz, radius)) { x, y, z in
            let dx = Double(x) - cx, dy = Double(y) - cy, dz = Double(z) - cz
            return dx * dx + dy * dy + dz * dz <= radius * radius
        }
        return failure == nil
    }

    func paintCylinder(z1: GSValue, radius: GSValue, color: GSValue) -> Bool {
        let (cx, cy, _) = staged
        guard failure == nil, let color = paintColor(color), let z0 = whole(staged.2), let z1 = integer(z1), let radius = number(radius), radius >= 0 else {
            return fail("model.cylinder expects a center x, y, integer z0, z1, a non-negative radius and a color in 0...255.")
        }
        fill(color, x: bounds(cx, radius), y: bounds(cy, radius), z: min(z0, z1)...max(z0, z1)) { x, y, _ in
            let dx = Double(x) - cx, dy = Double(y) - cy
            return dx * dx + dy * dy <= radius * radius
        }
        return failure == nil
    }

    func colorAt(x: GSValue, y: GSValue, z: GSValue) -> Int {
        guard let x = integer(x), let y = integer(y), let z = integer(z), contains(x, y, z) else { return 0 }
        return Int(cells[index(x, y, z)])
    }

    // MARK: - Helpers

    @GSExportableIgnore
    private func fill(_ color: UInt8, x: ClosedRange<Int>, y: ClosedRange<Int>, z: ClosedRange<Int>, where inside: (Int, Int, Int) -> Bool) {
        guard !cells.isEmpty else {
            _ = fail("Call model.size(x, y, z) before painting.")
            return
        }
        // Painting is clipped to the model; a shape reaching outside is not an error.
        let (x0, x1) = (max(x.lowerBound, 0), min(x.upperBound, sizeX - 1))
        let (y0, y1) = (max(y.lowerBound, 0), min(y.upperBound, sizeY - 1))
        let (z0, z1) = (max(z.lowerBound, 0), min(z.upperBound, sizeZ - 1))
        guard x0 <= x1, y0 <= y1, z0 <= z1 else { return }
        for z in z0...z1 {
            for y in y0...y1 {
                for x in x0...x1 where inside(x, y, z) { cells[index(x, y, z)] = color }
            }
        }
    }

    @GSExportableIgnore
    private func bounds(_ center: Double, _ radius: Double) -> ClosedRange<Int> {
        Int((center - radius).rounded(.down))...Int((center + radius).rounded(.up))
    }

    @GSExportableIgnore
    private func index(_ x: Int, _ y: Int, _ z: Int) -> Int { x + sizeX * (y + sizeY * z) }

    @GSExportableIgnore
    private func contains(_ x: Int, _ y: Int, _ z: Int) -> Bool {
        !cells.isEmpty && x >= 0 && y >= 0 && z >= 0 && x < sizeX && y < sizeY && z < sizeZ
    }

    @GSExportableIgnore
    private func fail(_ message: String) -> Bool {
        failure = failure ?? message
        return false
    }

    @GSExportableIgnore
    private func number(_ value: GSValue) -> Double? {
        if value.isInteger { return Double(value.toInteger) }
        if value.isDouble, value.toDouble.isFinite, abs(value.toDouble) < 1_000_000 { return value.toDouble }
        return nil
    }

    /// Whole numbers only; `3.0` from script arithmetic is accepted, `3.5` is not.
    @GSExportableIgnore
    private func integer(_ value: GSValue) -> Int? {
        number(value).flatMap(whole)
    }

    @GSExportableIgnore
    private func whole(_ number: Double) -> Int? {
        number == number.rounded() ? Int(number) : nil
    }

    @GSExportableIgnore
    private func paintColor(_ value: GSValue) -> UInt8? {
        guard let color = integer(value), (0...255).contains(color) else { return nil }
        return UInt8(color)
    }
}
