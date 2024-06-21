//
//  UIStackView.swift
//
//
//  Created by Vladislav Prusakov on 20.06.2024.
//

public class UIStackView: UIView {

    public enum Axis {
        case horizontal
        case vertical
    }

    public enum LayoutRule {
        case fillEqually
    }

    public var axis: Axis = .horizontal {
        didSet {
            setNeedsLayout()
        }
    }

    public var spacing: Float = 0 {
        didSet {
            setNeedsLayout()
        }
    }

    public var layoutRule: LayoutRule = .fillEqually {
        didSet {
            setNeedsLayout()
        }
    }

    public init(_ axis: Axis, children: [UIView]) {
        super.init(frame: .zero)
        self.axis = axis

        children.forEach {
            $0.frame.origin = [0, 0]
            self.addSubview($0)
        }
    }
    
    public required init(frame: Rect) {
        super.init(frame: frame)
    }

    public override func layoutSubviews() {
        if frame == .zero {
            super.layoutSubviews()
            return
        }

        let count = self.subviews.count

        var origin: Point = .zero

        for subview in self.subviews {
            var size: Size = .zero

            switch layoutRule {
            case .fillEqually:
                let proposalWidth = self.axis == .horizontal ? self.frame.width / Float(count) : self.frame.width
                let proposalHeight = self.axis == .vertical ? self.frame.height / Float(count) : self.frame.height
                let proposal = ProposedViewSize(
                    width: proposalWidth,
                    height: proposalHeight
                )

                size = subview.sizeThatFits(proposal)
            }

            subview.frame.size = size
            subview.frame.origin = origin

            if axis == .vertical {
                origin.y += spacing + size.height
            } else {
                origin.x += spacing + size.width
            }
        }
        
        super.layoutSubviews()
    }

}
