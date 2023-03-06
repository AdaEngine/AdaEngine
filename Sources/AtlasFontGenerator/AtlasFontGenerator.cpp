//
//  atlas_font_gen.cpp
//  
//
//  Created by v.prusakov on 3/4/23.
//

#include "atlas_font_gen.h"
#include "FontHolder.h"

// Get from Hazel
#define LCG_MULTIPLIER 6364136223846793005ull
#define LCG_INCREMENT 1442695040888963407ull

namespace ada_font {

struct GenerationConfig {
    int width;
    int height;
    int threads;
    msdf_atlas::GeneratorAttributes attributes;
};

using namespace msdf_atlas;

template <typename T, typename S, int N, GeneratorFunction<S, N> GEN_FN>
AtlasBitmap GenerateAtlas(
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
    
    AtlasBitmap result;
    result.bitmapWidth = bitmap.width;
    result.bitmapHeight = bitmap.height;
    result.pixels = bitmap.pixels;
    result.pixelsCount = bitmap.width * bitmap.height * sizeof(T) * N;
    
    return result;
}

FontAtlasGenerator::FontAtlasGenerator(const char* filePath, const char* fontName, const AtlasFontDescriptor& fontDescriptor) : m_FontData(new FontData())
{
    FontHolder fontHandler;
    bool success = fontHandler.loadFont(filePath);
    
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
    
    m_FontData->fontGeometry = FontGeometry(&m_FontData->glyphs);
    
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
    atlasPacker.setPadding(fontDescriptor.atlasImageType == ImageType::MSDF || fontDescriptor.atlasImageType == ImageType::MTSDF ? 0 : -1);
    
    atlasPacker.setScale(fontDescriptor.fontScale);
    atlasPacker.setPixelRange(fontDescriptor.atlasPixelRange);
    atlasPacker.setMiterLimit(fontDescriptor.miterLimit);
    
    int result = atlasPacker.pack(m_FontData->glyphs.data(), (int)m_FontData->glyphs.size());
    
    if (result != 0)
        return;
    
    int width = -1; int height = -1;
    atlasPacker.getDimensions(width, height);
    
    if (fontDescriptor.atlasImageType == ImageType::MSDF || fontDescriptor.atlasImageType == ImageType::MTSDF) {
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
    
    GenerationConfig config;
    config.width = width;
    config.height = height;
    config.threads = fontDescriptor.threads;
    config.attributes.config.overlapSupport = true;
    config.attributes.scanlinePass = true;
    
    AtlasBitmap bitmap;
    
    switch (fontDescriptor.atlasImageType) {
        case msdf_atlas::ImageType::HARD_MASK:
            break;
        case msdf_atlas::ImageType::SOFT_MASK:
            break;
        case msdf_atlas::ImageType::SDF:
            break;
        case msdf_atlas::ImageType::PSDF:
            break;
        case ImageType::MSDF:
            bitmap = GenerateAtlas<float, float, 3, msdfGenerator>(m_FontData->glyphs, m_FontData->fontGeometry, config);
            break;
        case ImageType::MTSDF:
            bitmap = GenerateAtlas<float, float, 4, mtsdfGenerator>(m_FontData->glyphs, m_FontData->fontGeometry, config);
            break;
    }
    
    m_Bitmap = bitmap;
}

AtlasBitmap FontAtlasGenerator::getBitmap() {
    return m_Bitmap;
}

}
