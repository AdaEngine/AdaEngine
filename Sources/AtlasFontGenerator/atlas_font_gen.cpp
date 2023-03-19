//
//  atlas_font_gen.cpp
//  
//
//  Created by v.prusakov on 3/19/23.
//

#include "atlas_font_gen.h"
#include <msdfgen.h>
#include <msdf_atlas_gen.h>
#include "AtlasFontGenerator.h"

typedef struct font_handle_s {
    ada::FontData *font_data;
} font_handle_t;

typedef struct font_glyph_s {
    const msdf_atlas::GlyphGeometry *glyph;
} font_glyph_t;

typedef struct font_generator_s {
    ada::FontAtlasGenerator *generator;
} font_generator_t;

font_generator_s* font_atlas_generator_create(const char* fontPath,
                                 const char* fontName,
                                 font_atlas_descriptor fontDescriptor) {
    auto font_generator = new ada::FontAtlasGenerator(fontPath, fontName, fontDescriptor);
    auto generator = new font_generator_s();
    generator->generator = font_generator;
    return generator;
}

font_handle_s* font_atlas_generator_get_font_data(font_generator_s* generator) {
    auto data = generator->generator->getFontData();
    font_handle_s* result = new font_handle_s();
    result->font_data = data;
    return result;
}

void font_handle_destroy(font_handle_s *fontHandle) {
    delete fontHandle->font_data;
    delete fontHandle;
}

AtlasBitmap* font_atlas_generator_generate_bitmap(font_generator_s* generator) {
    return generator->generator->generateAtlasBitmap();
}

const char* font_geometry_get_name(font_handle_s* fontData) {
    return fontData->font_data->fontGeometry.getName();
}

double font_geometry_get_scale(font_handle_s* fontData) {
    return fontData->font_data->fontGeometry.getGeometryScale();
}

size_t font_handle_get_glyphs_count(font_handle_s* fontData) {
    return fontData->font_data->glyphs.size();
}

void font_handle_get_advance(font_handle_s* fontData, double* advance, uint32_t currentUnicode, uint32_t nextUnicode) {
    fontData->font_data->fontGeometry.getAdvance(*advance, currentUnicode, nextUnicode);
}

FontMetrics font_geometry_get_metrics(font_handle_s* fontData) {
    auto metrics = fontData->font_data->fontGeometry.getMetrics();
    
    FontMetrics result;
    result.lineHeight = metrics.lineHeight;
    result.ascenderY = metrics.ascenderY;
    result.descenderY = metrics.descenderY;
    result.underlineY = metrics.underlineY;
    result.underlineThickness = metrics.underlineThickness;
    result.emSize = metrics.emSize;
    return result;
}

// MARK: GLYPH

font_glyph_s* font_handle_get_glyph_unicode(font_handle_s* fontData, uint32_t unicode) {
    const msdf_atlas::GlyphGeometry* glyph = fontData->font_data->fontGeometry.getGlyph(unicode);
    
    if (!glyph)
        return nullptr;
    
    font_glyph_s* result = new font_glyph_s();
    result->glyph = glyph;
    return result;
}

double font_glyph_get_advance(font_glyph_s *glyph) {
    return glyph->glyph->getAdvance();
}

void font_glyph_get_quad_atlas_bounds(font_glyph_s *glyph, double* l, double* b, double* r, double* t) {
    glyph->glyph->getQuadAtlasBounds(*l, *b, *r, *t);
}

void font_glyph_get_quad_plane_bounds(font_glyph_s *glyph, double* pl, double* pb, double* pr, double* pt) {
    glyph->glyph->getQuadPlaneBounds(*pl, *pb, *pr, *pt);
}
