//
//  FontHolder.cpp
//  
//
//  Created by v.prusakov on 3/4/23.
//

#include "FontHolder.h"

namespace ada {

bool FontHolder::loadFont(const char* fontPath) {
    if (ft && fontPath) {
        if (this->fontPath && !strcmp(fontPath, fontPath))
            return true;
        if (font)
            msdfgen::destroyFont(font);
        if ((font = msdfgen::loadFont(ft, fontPath))) {
            this->fontPath = fontPath;
            return true;
        }
        this->fontPath = nullptr;
    }
    return false;
}

}
