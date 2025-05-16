//
//  atlas_font_gen.cpp
//  AdaEngine
//
//  Created by v.prusakov on 3/4/23.
//

#include "assert.h"
#include "atlas_font_gen.h"
#include "FontHolder.h"
#include "AtlasFontGenerator.h"

// Get from Hazel
#define LCG_MULTIPLIER 6364136223846793005ull
#define LCG_INCREMENT 1442695040888963407ull

namespace ada {

struct GenerationConfig {
    int width;
    int height;
    int threads;
    msdf_atlas::GeneratorAttributes attributes;
};

using namespace msdf_atlas;

template <typename T, typename S, int N, GeneratorFunction<S, N> GEN_FN>
AtlasBitmap* GenerateAtlas(
                                 const std::vector<GlyphGeometry>& glyphs,
                                 const FontGeometry& fontGeometry,
                                 const GenerationConfig& config
                                 )
{
    ImmediateAtlasGenerator<S, N, GEN_FN, BitmapAtlasStorage<T, N>> generator(config.width, config.height);
    generator.setAttributes(config.attributes);
    generator.setThreadCount(config.threads);
    generator.generate(glyphs.data(), (int)glyphs.size());
    
    msdfgen::BitmapConstRef<T, N> bitmap = (msdfgen::BitmapConstRef<T, N>)generator.atlasStorage();
    
    AtlasBitmap* result = new AtlasBitmap();
    result->bitmapWidth = bitmap.width;
    result->bitmapHeight = bitmap.height;
    
    void *pixels = malloc(bitmap.width * bitmap.height * sizeof(T) * N);
    memcpy(pixels, bitmap.pixels, bitmap.width * bitmap.height * sizeof(T) * N);    
    result->pixels = pixels;
    result->pixelsCount = bitmap.width * bitmap.height * sizeof(T) * N;
    
    return result;
}

FontAtlasGenerator* font_atlas_generator_create(const char* fontPath,
                                                const char* fontName,
                                                const font_atlas_descriptor& fontDescriptor) {
                                                    FontHolder fontHandler;
    bool success = fontHandler.loadFont(fontPath);
    
    if (success) {
        assert("Can't load font");
    }
    
    Charset charset;
    
    // From ImGui
    static const uint32_t charsetRanges[] = {
        0x0020, 0x00FF, // Basic Latin + Latin Supplement
        0x0400, 0x052F, // Cyrillic + Cyrillic Supplement
        0x2DE0, 0x2DFF, // Cyrillic Extended-A
        0xA640, 0xA69F, // Cyrillic Extended-B
        0,
    };
    
    FontData* fontData = new FontData();
    fontData->fontGeometry = FontGeometry(&fontData->glyphs);
    
    for (int range = 0; range < 8; range += 2) {
        for (uint32_t c = charsetRanges[range]; c <= charsetRanges[range + 1]; c++)
            charset.add(c);
    }
    
    int loadedGlyphs = m_FontData->fontGeometry.loadCharset(fontHandler.getFont(), 1, charset);
    
    if (loadedGlyphs < m_FontData->glyphs.size()) {
        assert("Can't load all glyphs");
    }
    
    m_FontData->fontGeometry.setName(fontName);
    
    TightAtlasPacker atlasPacker;
    atlasPacker.setDimensionsConstraint(TightAtlasPacker::DimensionsConstraint::MULTIPLE_OF_FOUR_SQUARE);
    atlasPacker.setPadding(fontDescriptor.atlasImageType == AFG_ImageType::AFG_IMAGE_TYPE_MSDF || fontDescriptor.atlasImageType == AFG_ImageType::AFG_IMAGE_TYPE_MTSDF ? 0 : -1);
    
    atlasPacker.setScale(fontDescriptor.emFontScale);
    atlasPacker.setMinimumScale(12);
    atlasPacker.setPixelRange(fontDescriptor.atlasPixelRange);
    atlasPacker.setMiterLimit(fontDescriptor.miterLimit);
    
    int result = atlasPacker.pack(m_FontData->glyphs.data(), (int)m_FontData->glyphs.size());
    
    if (result != 0)
        return;
    
    atlasPacker.getDimensions(m_AtlasInfo.width, m_AtlasInfo.height);
    
    if (fontDescriptor.atlasImageType == AFG_ImageType::AFG_IMAGE_TYPE_MSDF || fontDescriptor.atlasImageType == AFG_ImageType::AFG_IMAGE_TYPE_MTSDF) {
        if (fontDescriptor.expensiveColoring) {
            Workload([&glyphs = m_FontData->glyphs, &fontDescriptor](int i, int threadNo) -> bool {
                unsigned long long glyphSeed = (LCG_MULTIPLIER * (fontDescriptor.coloringSeed ^ i) + LCG_INCREMENT) * !!fontDescriptor.coloringSeed;
                glyphs[i].edgeColoring(msdfgen::edgeColoringInkTrap, fontDescriptor.angleThreshold, glyphSeed);
                return true;
            }, (int)m_FontData->glyphs.size());
        } else {
            unsigned long glyphSeed = fontDescriptor.coloringSeed;
            for (GlyphGeometry &glyph : m_FontData->glyphs) {
                glyphSeed *= LCG_MULTIPLIER;
                glyph.edgeColoring(msdfgen::edgeColoringInkTrap, fontDescriptor.angleThreshold, glyphSeed);
            }
        }
    }
    return nullptr;
}

font_handle_t* font_atlas_generator_get_font_data(FontAtlasGenerator* generator) {
    return nullptr;
}
void font_handle_destroy(font_handle_t* fontHandle) {
    return;
}

AtlasBitmap* font_atlas_generator_generate_bitmap(FontAtlasGenerator* generator) {
    GenerationConfig config;
    config.width = generator->m_AtlasInfo.width;
    config.height = generator->m_AtlasInfo.height;
    config.threads = generator->m_fontDescriptor.threads;
    config.attributes.config.overlapSupport = true;
    config.attributes.scanlinePass = true;
    
    switch (m_fontDescriptor.atlasImageType) {
        case AFG_ImageType::AFG_IMAGE_TYPE_HARD_MASK:
            break;
        case AFG_ImageType::AFG_IMAGE_TYPE_SOFT_MASK:
            break;
        case AFG_ImageType::AFG_IMAGE_TYPE_SDF:
            break;
        case AFG_ImageType::AFG_IMAGE_TYPE_PSDF:
            break;
        case AFG_ImageType::AFG_IMAGE_TYPE_MSDF:
            return GenerateAtlas<float, float, 3, msdfGenerator>(m_FontData->glyphs, m_FontData->fontGeometry, config);
        case AFG_ImageType::AFG_IMAGE_TYPE_MTSDF:
            return GenerateAtlas<float, float, 4, mtsdfGenerator>(m_FontData->glyphs, m_FontData->fontGeometry, config);
    }
    
    return nullptr;
}

// FontAtlasGenerator::FontAtlasGenerator(const char* filePath, const char* fontName, const font_atlas_descriptor& fontDescriptor) : m_FontData(new FontData()), m_fontDescriptor(fontDescriptor)
// {
//     FontHolder fontHandler;
//     bool success = fontHandler.loadFont(filePath);
    
//     if (success) {
//         assert("Can't load font");
//     }
    
//     Charset charset;
    
//     // From ImGui
//     static const uint32_t charsetRanges[] = {
//         0x0020, 0x00FF, // Basic Latin + Latin Supplement
//         0x0400, 0x052F, // Cyrillic + Cyrillic Supplement
//         0x2DE0, 0x2DFF, // Cyrillic Extended-A
//         0xA640, 0xA69F, // Cyrillic Extended-B
//         0,
//     };
    
//     m_FontData->fontGeometry = FontGeometry(&m_FontData->glyphs);
    
//     for (int range = 0; range < 8; range += 2) {
//         for (uint32_t c = charsetRanges[range]; c <= charsetRanges[range + 1]; c++)
//             charset.add(c);
//     }
    
//     int loadedGlyphs = m_FontData->fontGeometry.loadCharset(fontHandler.getFont(), 1, charset);
    
//     if (loadedGlyphs < m_FontData->glyphs.size()) {
//         assert("Can't load all glyphs");
//     }
    
//     m_FontData->fontGeometry.setName(fontName);
    
//     TightAtlasPacker atlasPacker;
//     atlasPacker.setDimensionsConstraint(TightAtlasPacker::DimensionsConstraint::MULTIPLE_OF_FOUR_SQUARE);
//     atlasPacker.setPadding(fontDescriptor.atlasImageType == AFG_ImageType::AFG_IMAGE_TYPE_MSDF || fontDescriptor.atlasImageType == AFG_ImageType::AFG_IMAGE_TYPE_MTSDF ? 0 : -1);
    
//     atlasPacker.setScale(fontDescriptor.emFontScale);
//     atlasPacker.setMinimumScale(12);
//     atlasPacker.setPixelRange(fontDescriptor.atlasPixelRange);
//     atlasPacker.setMiterLimit(fontDescriptor.miterLimit);
    
//     int result = atlasPacker.pack(m_FontData->glyphs.data(), (int)m_FontData->glyphs.size());
    
//     if (result != 0)
//         return;
    
//     atlasPacker.getDimensions(m_AtlasInfo.width, m_AtlasInfo.height);
    
//     if (fontDescriptor.atlasImageType == AFG_ImageType::AFG_IMAGE_TYPE_MSDF || fontDescriptor.atlasImageType == AFG_ImageType::AFG_IMAGE_TYPE_MTSDF) {
//         if (fontDescriptor.expensiveColoring) {
//             Workload([&glyphs = m_FontData->glyphs, &fontDescriptor](int i, int threadNo) -> bool {
//                 unsigned long long glyphSeed = (LCG_MULTIPLIER * (fontDescriptor.coloringSeed ^ i) + LCG_INCREMENT) * !!fontDescriptor.coloringSeed;
//                 glyphs[i].edgeColoring(msdfgen::edgeColoringInkTrap, fontDescriptor.angleThreshold, glyphSeed);
//                 return true;
//             }, (int)m_FontData->glyphs.size());
//         } else {
//             unsigned long glyphSeed = fontDescriptor.coloringSeed;
//             for (GlyphGeometry &glyph : m_FontData->glyphs) {
//                 glyphSeed *= LCG_MULTIPLIER;
//                 glyph.edgeColoring(msdfgen::edgeColoringInkTrap, fontDescriptor.angleThreshold, glyphSeed);
//             }
//         }
//     }

// }

// AtlasBitmap* FontAtlasGenerator::generateAtlasBitmap() {
//     GenerationConfig config;
//     config.width = m_AtlasInfo.width;
//     config.height = m_AtlasInfo.height;
//     config.threads = m_fontDescriptor.threads;
//     config.attributes.config.overlapSupport = true;
//     config.attributes.scanlinePass = true;
    
//     switch (m_fontDescriptor.atlasImageType) {
//         case AFG_ImageType::AFG_IMAGE_TYPE_HARD_MASK:
//             break;
//         case AFG_ImageType::AFG_IMAGE_TYPE_SOFT_MASK:
//             break;
//         case AFG_ImageType::AFG_IMAGE_TYPE_SDF:
//             break;
//         case AFG_ImageType::AFG_IMAGE_TYPE_PSDF:
//             break;
//         case AFG_ImageType::AFG_IMAGE_TYPE_MSDF:
//             return GenerateAtlas<float, float, 3, msdfGenerator>(m_FontData->glyphs, m_FontData->fontGeometry, config);
//         case AFG_ImageType::AFG_IMAGE_TYPE_MTSDF:
//             return GenerateAtlas<float, float, 4, mtsdfGenerator>(m_FontData->glyphs, m_FontData->fontGeometry, config);
//     }
    
//     return nullptr;
// }

}
