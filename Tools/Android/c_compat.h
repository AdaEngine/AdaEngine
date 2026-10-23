// Gravity's C sources use the POSIX string declarations. SwiftPM's -Xcc flags
// also reach preprocessed assembly (for example swift-crypto), which must not
// receive C declarations.
#ifndef __ASSEMBLER__
#include <strings.h>
#endif
