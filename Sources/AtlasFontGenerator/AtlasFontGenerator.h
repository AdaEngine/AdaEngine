//
//  AtlasFontGenerator.h
//  
//
//  Created by v.prusakov on 3/4/23.
//

#ifndef AtlasFontGenerator_h
#define AtlasFontGenerator_h

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
};

struct FontData {
    msdf_atlas::FontGeometry fontGeometry;
    std::vector<msdf_atlas::GlyphGeometry> glyphs;
};

/// Generate font atlas from font path and specific font description.
class FontAtlasGenerator {
public:
    FontAtlasGenerator(
                       const char* fontPath,
                       const char* fontName,
                       const AtlasFontDescriptor& fontDescriptor
                       );
    
    
    /// Returns bitmap representation.
    AtlasBitmap getBitmap();
    
    
    /// For some reasons we should store font data on Swift side.
    /// And you must delete memory when FontData isn't used anymore!
    const FontData* getFontData() {
        return m_FontData;
    }
    
private:    
    FontData* m_FontData;
    
    AtlasBitmap m_Bitmap;
};

}
#endif /* AtlasFontGenerator_h */

