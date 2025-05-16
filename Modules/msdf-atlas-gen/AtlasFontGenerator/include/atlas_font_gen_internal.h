#ifndef atlas_font_gen_internal_h
#define atlas_font_gen_internal_h

#include <stdint.h>
#include "atlas_font_gen.h"

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations
typedef struct FontGeometry FontGeometry;
typedef struct GlyphGeometry GlyphGeometry;
typedef struct FontData FontData;
typedef struct FontAtlasGenerator FontAtlasGenerator;

// Structure definitions
struct FontGeometry {
    const char* name;
    double geometryScale;
    double (*getAdvance)(struct FontGeometry* self, uint32_t currentUnicode, uint32_t nextUnicode);
    struct GlyphGeometry* (*getGlyph)(struct FontGeometry* self, uint32_t unicode);
    struct FontMetrics (*getMetrics)(struct FontGeometry* self);
};

struct GlyphGeometry {
    double advance;
    void (*getQuadAtlasBounds)(struct GlyphGeometry* self, double* l, double* b, double* r, double* t);
    void (*getQuadPlaneBounds)(struct GlyphGeometry* self, double* pl, double* pb, double* pr, double* pt);
};

struct FontData {
    struct FontGeometry fontGeometry;
    struct GlyphGeometry* glyphs;
    size_t glyphsCount;
};

struct FontAtlasGenerator {
    FontData* fontData;
    char* fontPath;
    char* fontName;
    struct font_atlas_descriptor descriptor;
    AtlasBitmap* (*generateAtlasBitmap)(struct FontAtlasGenerator* self);
};

// Implementation of font_handle_s
struct font_handle_s {
    FontData* font_data;
};

// Implementation of font_glyph_s
struct font_glyph_s {
    const GlyphGeometry* glyph;
};

// Implementation of font_generator_s
struct font_generator_s {
    FontAtlasGenerator* generator;
};

#ifdef __cplusplus
}
#endif

#endif /* atlas_font_gen_internal_h */ 