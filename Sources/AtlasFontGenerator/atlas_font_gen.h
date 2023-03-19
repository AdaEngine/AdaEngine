//
//  atlas_font_gen.h
//  
//
//  Created by v.prusakov on 3/4/23.
//

#ifndef atlas_font_gen_h
#define atlas_font_gen_h

#include <vector>

/// Type of atlas image contents
typedef enum AFG_ImageType {
    /// Rendered glyphs without anti-aliasing (two colors only)
    AFG_IMAGE_TYPE_HARD_MASK,
    /// Rendered glyphs with anti-aliasing
    AFG_IMAGE_TYPE_SOFT_MASK,
    /// Signed (true) distance field
    AFG_IMAGE_TYPE_SDF,
    /// Signed pseudo-distance field
    AFG_IMAGE_TYPE_PSDF,
    /// Multi-channel signed distance field
    AFG_IMAGE_TYPE_MSDF,
    /// Multi-channel & true signed distance field
    AFG_IMAGE_TYPE_MTSDF
} AFG_ImageType;

typedef struct AtlasBitmap {
    int bitmapWidth;
    int bitmapHeight;
    void *pixels;
    int pixelsCount;
} AtlasBitmap;

/// Global metrics of a typeface (in font units).
typedef struct FontMetrics {
    /// The size of one EM.
    double emSize;
    /// The vertical position of the ascender and descender relative to the baseline.
    double ascenderY, descenderY;
    /// The vertical difference between consecutive baselines.
    double lineHeight;
    /// The vertical position and thickness of the underline.
    double underlineY, underlineThickness;
} FontMetrics;

typedef struct font_atlas_descriptor {
    double fontScale;
    double minimumScale;
    bool expensiveColoring;
    double angleThreshold;
    unsigned long coloringSeed;
    
    int threads;
    
    AFG_ImageType atlasImageType;
    double atlasPixelRange;
    double miterLimit;
} font_atlas_descriptor;

typedef struct font_handle_s font_handle_t;
typedef struct font_generator_s font_generator_t;
typedef struct font_glyph_s font_glyph_t;

#ifdef __cplusplus
extern "C" {
#endif

font_generator_s* font_atlas_generator_create(const char* fontPath,
                                              const char* fontName,
                                              font_atlas_descriptor fontDescriptor);

font_handle_s* font_atlas_generator_get_font_data(font_generator_s* generator);
void font_handle_destroy(font_handle_s *fontHandle);

AtlasBitmap* font_atlas_generator_generate_bitmap(font_generator_s* generator);

const char* font_geometry_get_name(font_handle_s* fontData);
double font_geometry_get_scale(font_handle_s* fontData);

size_t font_handle_get_glyphs_count(font_handle_s* fontData);

void font_handle_get_advance(font_handle_s* fontData, double* advance, uint32_t currentUnicode, uint32_t nextUnicode);

FontMetrics font_geometry_get_metrics(font_handle_s* fontData);

// MARK: GLYPH

font_glyph_s* font_handle_get_glyph_unicode(font_handle_s* fontData, uint32_t unicode);
double font_glyph_get_advance(font_glyph_s *glyph);
void font_glyph_get_quad_atlas_bounds(font_glyph_s *glyph, double* l, double* b, double* r, double* t);
void font_glyph_get_quad_plane_bounds(font_glyph_s *glyph, double* pl, double* pb, double* pr, double* pt);


#ifdef __cplusplus
}
#endif

#endif /* atlas_font_gen_h */
