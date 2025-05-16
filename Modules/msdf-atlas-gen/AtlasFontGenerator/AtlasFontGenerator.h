//
//  AtlasFontGenerator.h
//  AdaEngine
//
//  Created by v.prusakov on 3/4/23.
//

#ifndef AtlasFontGenerator_h
#define AtlasFontGenerator_h

#include "atlas_font_gen.h"

typedef struct AtlasInfo {
    int width;
    int height;
} AtlasInfo;

typedef struct FontData {
    // msdf_atlas::FontGeometry fontGeometry;
    // std::vector<msdf_atlas::GlyphGeometry> glyphs;
    AtlasInfo atlasInfo;
    unsigned long glyphsCount;
} FontData;

typedef struct FontAtlasGenerator {
    FontData* fontData;
    void *generator;
} FontAtlasGenerator;

FontAtlasGenerator* font_atlas_generator_create(const char* fontPath,
                                                const char* fontName,
                                                const font_atlas_descriptor& fontDescriptor);

font_handle_t* font_atlas_generator_get_font_data(FontAtlasGenerator* generator);
void font_handle_destroy(font_handle_t* fontHandle);
AtlasBitmap* font_atlas_generator_generate_bitmap(FontAtlasGenerator* generator);


// /// Generate font atlas from font path and specific font description.
// class FontAtlasGenerator {
// public:
//     FontAtlasGenerator(const char* fontPath,
//                        const char* fontName,
//                        const font_atlas_descriptor& fontDescriptor);
    
    
//     /// Returns bitmap representation.
//     AtlasBitmap* generateAtlasBitmap();
    
    
//     /// For some reasons we should store font data on Swift side.
//     /// And you must delete memory when FontData isn't used anymore!
//     FontData* getFontData() {
//         return m_FontData;
//     }
    
// private:    
//     FontData* m_FontData;
    
//     font_atlas_descriptor m_fontDescriptor;
    
//     struct {
//         int width = -1;
//         int height = -1;
//     } m_AtlasInfo;
// };
#endif /* AtlasFontGenerator_h */