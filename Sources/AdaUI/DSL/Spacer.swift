//
//  Spacer.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 24.06.2024.
//

import Math

/// A flexible space that expands along the major axis of its containing stack layout,
/// or on both axes if not contained in a stack.
public struct Spacer: View, ViewNodeBuilder {

    public typealias Body = Never
    public var body: Never { fatalError() }

    /// The minimum length this spacer can be shrunk to, along the axis or axes of expansion.
    public var minLength: Float?

    public init(minLength: Float? = nil) {
        self.minLength = minLength
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        SpacerViewNode(minLength: minLength, content: self)
    }
}

final class SpacerViewNode: ViewNode {
    let minLength: Float?

    init(minLength: Float?, content: Spacer) {
        self.minLength = minLength
        super.init(content: content)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        let minLength = self.minLength ?? 0

        switch layoutProperties.stackOrientation {
        case .horizontal:
            if proposal == .zero {
                return Size(width: minLength, height: 0)
            }
            let width = max(proposal.width ?? minLength, minLength)
            return Size(width: width, height: 0)
        case .vertical:
            if proposal == .zero {
                return Size(width: 0, height: minLength)
            }
            let height = max(proposal.height ?? minLength, minLength)
            return Size(width: 0, height: height)
        default:
            if proposal == .zero {
                return Size(width: minLength, height: minLength)
            }

            var size = proposal.replacingUnspecifiedDimensions(by: Size(width: minLength, height: minLength))
            size.width = max(size.width, minLength)
            size.height = max(size.height, minLength)
            return size
        }
    }
}
