//
// Created by v.prusakov on 12/25/22.
//

#if canImport(MetalKit)
import MetalKit
import AdaEngine

public class AEView: MetalView {

    public init(frame: CGRect) {
        super.init(frame: frame, device: nil)
    }

    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


}

#endif