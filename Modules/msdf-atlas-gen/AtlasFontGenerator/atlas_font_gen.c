//
//  atlas_font_gen.cpp
//  AdaEngine
//
//  Created by v.prusakov on 3/19/23.
//

#include "atlas_font_gen.h"
#include "atlas_font_gen_internal.h"
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#ifdef _WIN32
#include <crtdbg.h>
#endif

// Forward declarations
// struct FontGeometry;
// struct GlyphGeometry;
// struct FontMetrics;
// struct AtlasBitmap;
// struct font_atlas_descriptor;

// typedef struct FontGeometry {
//     const char* name;
//     double geometryScale;
//     double (*getAdvance)(struct FontGeometry* self, uint32_t currentUnicode, uint32_t nextUnicode);
//     struct GlyphGeometry* (*getGlyph)(struct FontGeometry* self, uint32_t unicode);
//     struct FontMetrics (*getMetrics)(struct FontGeometry* self);
// } FontGeometry;

// typedef struct GlyphGeometry {
//     double advance;
//     void (*getQuadAtlasBounds)(struct GlyphGeometry* self, double* l, double* b, double* r, double* t);
//     void (*getQuadPlaneBounds)(struct GlyphGeometry* self, double* pl, double* pb, double* pr, double* pt);
// } GlyphGeometry;

// typedef struct FontAtlasGenerator {
//     FontData* fontData;
//     char* fontPath;
//     char* fontName;
//     struct font_atlas_descriptor descriptor;
//     AtlasBitmap* (*generateAtlasBitmap)(struct FontAtlasGenerator* self);
// } FontAtlasGenerator;

// // Implementation of font_handle_s
// struct font_handle_s {
//     FontData* font_data;
// };

// // Implementation of font_glyph_s
// struct font_glyph_s {
//     const GlyphGeometry* glyph;
// };

// // Implementation of font_generator_s
// struct font_generator_s {
//     FontAtlasGenerator* generator;
// };

// Function implementations
struct font_generator_s* font_atlas_generator_create(const char* fontPath,
                                                   const char* fontName,
                                                   struct font_atlas_descriptor fontDescriptor) {
    FontAtlasGenerator* font_generator = (FontAtlasGenerator*)malloc(sizeof(FontAtlasGenerator));
    if (!font_generator) return NULL;
    
    font_generator->fontPath = _strdup(fontPath);
    font_generator->fontName = _strdup(fontName);
    font_generator->descriptor = fontDescriptor;
    
    struct font_generator_s* generator = (struct font_generator_s*)malloc(sizeof(struct font_generator_s));
    if (!generator) {
        free(font_generator->fontPath);
        free(font_generator->fontName);
        free(font_generator);
        return NULL;
    }
    
    generator->generator = font_generator;
    return generator;
}

struct font_handle_s* font_atlas_generator_get_font_data(struct font_generator_s* generator) {
    if (!generator || !generator->generator) return NULL;
    
    struct font_handle_s* result = (struct font_handle_s*)malloc(sizeof(struct font_handle_s));
    if (!result) return NULL;
    
    result->font_data = generator->generator->fontData;
    return result;
}

void font_handle_destroy(struct font_handle_s* fontHandle) {
    if (!fontHandle) return;
    
    if (fontHandle->font_data) {
        free(fontHandle->font_data);
    }
    free(fontHandle);
}

AtlasBitmap* font_atlas_generator_generate_bitmap(struct font_generator_s* generator) {
    if (!generator || !generator->generator) return NULL;
    return generator->generator->generateAtlasBitmap(generator->generator);
}

const char* font_geometry_get_name(struct font_handle_s* fontData) {
    if (!fontData || !fontData->font_data) return NULL;
    return fontData->font_data->fontGeometry.name;
}

double font_geometry_get_scale(struct font_handle_s* fontData) {
    if (!fontData || !fontData->font_data) return 0.0;
    return fontData->font_data->fontGeometry.geometryScale;
}

unsigned long font_handle_get_glyphs_count(struct font_handle_s* fontData) {
    if (!fontData || !fontData->font_data) return 0;
    return fontData->font_data->glyphsCount;
}

void font_handle_get_advance(struct font_handle_s* fontData, double* advance, 
                           uint32_t currentUnicode, uint32_t nextUnicode) {
    if (!fontData || !fontData->font_data || !advance) return;
    *advance = fontData->font_data->fontGeometry.getAdvance(&fontData->font_data->fontGeometry,
                                                          currentUnicode, nextUnicode);
}

FontMetrics font_geometry_get_metrics(struct font_handle_s* fontData) {
    FontMetrics result = {0};
    if (!fontData || !fontData->font_data) return result;
    
    return fontData->font_data->fontGeometry.getMetrics(&fontData->font_data->fontGeometry);
}

struct font_glyph_s* font_handle_get_glyph_unicode(struct font_handle_s* fontData, uint32_t unicode) {
    if (!fontData || !fontData->font_data) return NULL;
    
    const GlyphGeometry* glyph = fontData->font_data->fontGeometry.getGlyph(&fontData->font_data->fontGeometry, unicode);
    if (!glyph) return NULL;
    
    struct font_glyph_s* result = (struct font_glyph_s*)malloc(sizeof(struct font_glyph_s));
    if (!result) return NULL;
    
    result->glyph = glyph;
    return result;
}

double font_glyph_get_advance(struct font_glyph_s* glyph) {
    if (!glyph || !glyph->glyph) return 0.0;
    return glyph->glyph->advance;
}

void font_glyph_get_quad_atlas_bounds(struct font_glyph_s* glyph, double* l, double* b, double* r, double* t) {
    if (!glyph || !glyph->glyph || !l || !b || !r || !t) return;
    glyph->glyph->getQuadAtlasBounds((GlyphGeometry*)glyph->glyph, l, b, r, t);
}

void font_glyph_get_quad_plane_bounds(struct font_glyph_s* glyph, double* pl, double* pb, double* pr, double* pt) {
    if (!glyph || !glyph->glyph || !pl || !pb || !pr || !pt) return;
    glyph->glyph->getQuadPlaneBounds((GlyphGeometry*)glyph->glyph, pl, pb, pr, pt);
}
