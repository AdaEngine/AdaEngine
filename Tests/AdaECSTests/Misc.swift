import Testing
@_spi(Internal) @testable import AdaECS
import Math

@Component
struct Transform: Hashable {
    var position: Vector3 = .zero
}

@Component
struct Velocity: Hashable {
    var velocity: Vector3 = .zero
}

struct Gravity: Resource, Hashable {
    var value: Vector3
}