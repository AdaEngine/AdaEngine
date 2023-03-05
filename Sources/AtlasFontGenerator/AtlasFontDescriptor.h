//
//  FontAtlasGenerator.h
//  
//
//  Created by v.prusakov on 3/4/23.
//

#ifndef FontAtlasGenerator_h
#define FontAtlasGenerator_h

#include <msdfgen.h>
#include <msdf_atlas_gen.h>
#include <string>

namespace ada_font {

struct AtlasFontDescriptor {
    double fontScale;
    double minimumScale;
    bool expensiveColoring;
    double angleThreshold;
    unsigned long coloringSeed;
    
    int threads;
    
    msdf_atlas::ImageType atlasImageType;
    double atlasPixelRange;
    double miterLimit;
};

struct AtlasBitmap {
    int bitmapWidth;
    int bitmapHeight;
    const void *pixels;
    int pixelsCount;
    
    std::vector<msdf_atlas::GlyphBox> layout;
};

struct FontData {
    msdf_atlas::FontGeometry fontGeometry;
    std::vector<msdf_atlas::GlyphGeometry> glyps;
};

class FontAtlasGenerator {
public:
    FontAtlasGenerator(const char* fontPath, const char* fontName, const AtlasFontDescriptor& fontDescriptor);
    
    AtlasBitmap getBitmap();
    FontData getFontData() {
        return m_FontData;
    }
    
private:    
    FontData m_FontData;
    
    AtlasBitmap m_Bitmap;
};

}
#endif /* FontAtlasGenerator_h */

