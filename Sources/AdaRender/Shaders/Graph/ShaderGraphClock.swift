import AdaECS

/// A world-relative clock avoids precision loss from converting system uptime to Float.
package struct ShaderGraphClock: Resource {
    package var elapsed: Float = 0

    package mutating func advance(delta: Float) {
        // A newly started scheduler can report time since boot on its first frame.
        if delta.isFinite, delta >= 0, delta <= 1 { elapsed += delta }
    }
}
