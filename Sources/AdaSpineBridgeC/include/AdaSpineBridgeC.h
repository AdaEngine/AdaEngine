#ifndef ADA_SPINE_BRIDGE_H
#define ADA_SPINE_BRIDGE_H

#include <stdint.h>

typedef struct AdaSpinePlayer AdaSpinePlayer;
typedef struct AdaSpineBone {
    const char *name;
    int parentIndex, active;
    float x, y, endX, endY;
} AdaSpineBone;
typedef struct AdaSpineVertex {
    float x, y, u, v;
    float r, g, b, a;
    float darkR, darkG, darkB, darkA;
} AdaSpineVertex;

typedef struct AdaSpineDraw {
    int pageIndex;
    int blendMode;
    int premultipliedAlpha;
    int vertexCount;
    const AdaSpineVertex *vertices;
    int indexCount;
    const uint32_t *indices;
} AdaSpineDraw;

/* All returned strings and draw buffers belong to the player. */
AdaSpinePlayer *ada_spine_create(const unsigned char *data, int length, int binary,
                               const char *atlas, float scale, char *error, int errorCapacity);
void ada_spine_dispose(AdaSpinePlayer *player);
int ada_spine_animation_count(const AdaSpinePlayer *player);
const char *ada_spine_animation_name(const AdaSpinePlayer *player, int index);
int ada_spine_skin_count(const AdaSpinePlayer *player);
const char *ada_spine_skin_name(const AdaSpinePlayer *player, int index);
int ada_spine_page_count(const AdaSpinePlayer *player);
const char *ada_spine_page_name(const AdaSpinePlayer *player, int index);
int ada_spine_play(AdaSpinePlayer *player, const char *name, int loop, float mix);
int ada_spine_skin(AdaSpinePlayer *player, const char *name);
void ada_spine_update(AdaSpinePlayer *player, float delta);
void ada_spine_reset(AdaSpinePlayer *player);
float ada_spine_time(const AdaSpinePlayer *player);
int ada_spine_is_complete(const AdaSpinePlayer *player);
int ada_spine_draw_count(AdaSpinePlayer *player);
AdaSpineDraw ada_spine_draw(AdaSpinePlayer *player, int index);
int ada_spine_bone_count(const AdaSpinePlayer *player);
AdaSpineBone ada_spine_bone(const AdaSpinePlayer *player, int index);

#endif
