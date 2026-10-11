import Math

/// Keeps normal window geometry separate from the temporary immersive dock.
struct EditorVRWindowGeometry {
    enum Presentation: Equatable { case chooser, studio, dock }

    private(set) var presentation: Presentation = .chooser
    private(set) var studioSize = Size(width: 1600, height: 900)
    private(set) var chooserSize = Size(width: 1024, height: 700)
    private(set) var requestedSize = Size(width: 1024, height: 700)
    private(set) var request = 0
    private var pendingSize: Size?

    func size(for presentation: Presentation) -> Size {
        switch presentation {
        case .chooser: chooserSize
        case .studio: studioSize
        case .dock: Size(width: 824, height: 132)
        }
    }

    mutating func transition(to next: Presentation) {
        guard next != presentation else { return }
        presentation = next
        requestSize(size(for: next))
    }

    mutating func wide() {
        guard presentation == .studio else { return }
        requestSize(Size(width: 2200, height: 900))
    }

    mutating func observe(_ size: Size) {
        guard presentation != .dock, size.width.isFinite, size.height.isFinite,
            size.width >= (presentation == .studio ? 1000 : 900), size.height >= 600 else { return }
        if let pendingSize {
            // Ignore intermediate geometry emitted while native bounds expand from the dock.
            guard abs(size.width - pendingSize.width) <= 1, abs(size.height - pendingSize.height) <= 1 else { return }
            self.pendingSize = nil
        }
        switch presentation {
        case .studio: studioSize = size
        case .chooser: chooserSize = size
        case .dock: break
        }
    }

    mutating func rejectRequest() { pendingSize = nil }

    private mutating func requestSize(_ size: Size) {
        requestedSize = size
        pendingSize = presentation == .dock ? nil : size
        request += 1
    }
}
