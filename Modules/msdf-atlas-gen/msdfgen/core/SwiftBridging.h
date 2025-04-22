//
//  SwiftBridging.h
//  
//
//  Created by v.prusakov on 3/3/23.
//

#ifndef SwiftBridging_h
#define SwiftBridging_h

// annotate this macro to generate class interface for swift.
#define AS_SWIFT_CLASS \
            __attribute__((swift_attr("import_as_ref"))) \
            __attribute__((swift_attr("retain:immortal"))) \
            __attribute__((swift_attr("release:immortal")))

#endif /* SwiftBridging_h */
