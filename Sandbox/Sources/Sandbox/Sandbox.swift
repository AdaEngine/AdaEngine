import AppKit
import box2d

class MyView: NSView {
    override func awakeFromNib() {
        super.awakeFromNib()
        
        let contact = b2CircleContact()
        
//        glslang_program_create()
    }
}

let view = MyView()
