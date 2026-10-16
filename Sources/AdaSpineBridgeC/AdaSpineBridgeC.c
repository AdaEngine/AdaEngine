#include "AdaSpineBridgeC.h"
#include <spine/spine.h>
#include <spine/extension.h>
#include <limits.h>
#include <stdio.h>

typedef struct OwnedDraw {
    AdaSpineDraw draw;
    int vertexCapacity, indexCapacity;
} OwnedDraw;

struct AdaSpinePlayer {
    spAtlas *atlas;
    spSkeletonData *data;
    spSkeleton *skeleton;
    spAnimationStateData *stateData;
    spAnimationState *state;
    spSkeletonClipping *clipping;
    float *world;
    int worldCapacity;
    OwnedDraw *draws;
    int drawCount;
};

/* Texture upload and filesystem IO belong to Swift's asset loader. */
void _spAtlasPage_createTexture(spAtlasPage *page, const char *path) { (void)page; (void)path; }
void _spAtlasPage_disposeTexture(spAtlasPage *page) { (void)page; }
char *_spUtil_readFile(const char *path, int *length) { (void)path; *length = 0; return NULL; }

static void setError(char *buffer, int capacity, const char *message) {
    if (buffer && capacity > 0) snprintf(buffer, (size_t)capacity, "%s", message ? message : "Invalid Spine data.");
}

void ada_spine_dispose(AdaSpinePlayer *player) {
    if (!player) return;
    if (player->draws) {
        for (int i = 0; i < player->skeleton->slotsCount; ++i) {
            free((void *)player->draws[i].draw.vertices);
            free((void *)player->draws[i].draw.indices);
        }
    }
    free(player->draws);
    free(player->world);
    if (player->clipping) spSkeletonClipping_dispose(player->clipping);
    if (player->state) spAnimationState_dispose(player->state);
    if (player->stateData) spAnimationStateData_dispose(player->stateData);
    if (player->skeleton) spSkeleton_dispose(player->skeleton);
    if (player->data) spSkeletonData_dispose(player->data);
    if (player->atlas) spAtlas_dispose(player->atlas);
    free(player);
}

AdaSpinePlayer *ada_spine_create(const unsigned char *data, int length, int binary,
                               const char *atlas, float scale, char *error, int errorCapacity) {
    if (!data || length <= 0 || !atlas || strlen(atlas) > INT_MAX || !isfinite(scale) || scale <= 0) {
        setError(error, errorCapacity, "Empty skeleton/atlas or invalid scale.");
        return NULL;
    }
    AdaSpinePlayer *player = calloc(1, sizeof(AdaSpinePlayer));
    if (!player) { setError(error, errorCapacity, "Out of memory."); return NULL; }
    player->atlas = spAtlas_create(atlas, (int)strlen(atlas), "", NULL);
    if (!player->atlas || !player->atlas->pages) {
        setError(error, errorCapacity, "The Spine atlas has no texture pages.");
        ada_spine_dispose(player);
        return NULL;
    }
    for (spAtlasPage *page = player->atlas->pages; page; page = page->next) {
        if (page->width <= 0 || page->height <= 0) {
            setError(error, errorCapacity, "Spine atlas pages must declare a positive size.");
            ada_spine_dispose(player);
            return NULL;
        }
    }
    if (binary) {
        spSkeletonBinary *reader = spSkeletonBinary_create(player->atlas);
        reader->scale = scale;
        player->data = spSkeletonBinary_readSkeletonData(reader, data, length);
        if (!player->data) setError(error, errorCapacity, reader->error);
        spSkeletonBinary_dispose(reader);
    } else {
        char *json = malloc((size_t)length + 1);
        if (!json) { setError(error, errorCapacity, "Out of memory."); ada_spine_dispose(player); return NULL; }
        memcpy(json, data, (size_t)length);
        json[length] = 0;
        spSkeletonJson *reader = spSkeletonJson_create(player->atlas);
        reader->scale = scale;
        player->data = spSkeletonJson_readSkeletonData(reader, json);
        if (!player->data) setError(error, errorCapacity, reader->error);
        spSkeletonJson_dispose(reader);
        free(json);
    }
    if (!player->data) { ada_spine_dispose(player); return NULL; }
    player->skeleton = spSkeleton_create(player->data);
    player->stateData = spAnimationStateData_create(player->data);
    player->state = spAnimationState_create(player->stateData);
    player->clipping = spSkeletonClipping_create();
    player->draws = calloc((size_t)player->skeleton->slotsCount + 1, sizeof(OwnedDraw));
    if (!player->draws) { setError(error, errorCapacity, "Out of memory."); ada_spine_dispose(player); return NULL; }
    spSkeleton_updateWorldTransform(player->skeleton, SP_PHYSICS_RESET);
    return player;
}

int ada_spine_animation_count(const AdaSpinePlayer *p) { return p->data->animationsCount; }
const char *ada_spine_animation_name(const AdaSpinePlayer *p, int i) { return p->data->animations[i]->name; }
int ada_spine_skin_count(const AdaSpinePlayer *p) { return p->data->skinsCount; }
const char *ada_spine_skin_name(const AdaSpinePlayer *p, int i) { return p->data->skins[i]->name; }
int ada_spine_page_count(const AdaSpinePlayer *p) {
    int count = 0;
    for (spAtlasPage *page = p->atlas->pages; page; page = page->next) ++count;
    return count;
}
const char *ada_spine_page_name(const AdaSpinePlayer *p, int index) {
    spAtlasPage *page = p->atlas->pages;
    while (index-- > 0 && page) page = page->next;
    return page ? page->name : "";
}

int ada_spine_play(AdaSpinePlayer *p, const char *name, int loop, float mix) {
    spAnimation *animation = spSkeletonData_findAnimation(p->data, name);
    if (!animation) return 0;
    spTrackEntry *entry = spAnimationState_setAnimation(p->state, 0, animation, loop);
    entry->mixDuration = mix;
    spAnimationState_apply(p->state, p->skeleton);
    spSkeleton_updateWorldTransform(p->skeleton, SP_PHYSICS_POSE);
    return 1;
}
int ada_spine_skin(AdaSpinePlayer *p, const char *name) {
    if (!spSkeleton_setSkinByName(p->skeleton, name)) return 0;
    spSkeleton_setSlotsToSetupPose(p->skeleton);
    spAnimationState_apply(p->state, p->skeleton);
    spSkeleton_updateWorldTransform(p->skeleton, SP_PHYSICS_POSE);
    return 1;
}
void ada_spine_update(AdaSpinePlayer *p, float delta) {
    spSkeleton_update(p->skeleton, delta);
    spAnimationState_update(p->state, delta);
    spAnimationState_apply(p->state, p->skeleton);
    spSkeleton_updateWorldTransform(p->skeleton, SP_PHYSICS_UPDATE);
}
void ada_spine_reset(AdaSpinePlayer *p) {
    spAnimationState_clearTracks(p->state);
    spSkeleton_setToSetupPose(p->skeleton);
    p->skeleton->time = 0;
    spSkeleton_updateWorldTransform(p->skeleton, SP_PHYSICS_RESET);
}
float ada_spine_time(const AdaSpinePlayer *p) {
    spTrackEntry *entry = spAnimationState_getCurrent(p->state, 0);
    return entry ? entry->trackTime : 0;
}
int ada_spine_is_complete(const AdaSpinePlayer *p) {
    spTrackEntry *entry = spAnimationState_getCurrent(p->state, 0);
    return !entry || (!entry->loop && entry->trackTime >= entry->animationEnd);
}

int ada_spine_draw_count(AdaSpinePlayer *p) {
    static unsigned short quadIndices[] = {0, 1, 2, 2, 3, 0};
    p->drawCount = 0;
    spSkeletonClipping_clipEnd2(p->clipping);
    for (int i = 0; i < p->skeleton->slotsCount; ++i) {
        spSlot *slot = p->skeleton->drawOrder[i];
        spAttachment *attachment = slot->attachment;
        if (!slot->bone->active || !attachment || slot->color.a == 0) {
            spSkeletonClipping_clipEnd(p->clipping, slot);
            continue;
        }
        if (attachment->type == SP_ATTACHMENT_CLIPPING) {
            spSkeletonClipping_clipStart(p->clipping, slot, (spClippingAttachment *)attachment);
            continue;
        }
        spColor color;
        spAtlasRegion *region = NULL;
        float *uvs = NULL;
        unsigned short *indices = NULL;
        int worldCount = 0, indexCount = 0;
        if (attachment->type == SP_ATTACHMENT_REGION) worldCount = 8;
        else if (attachment->type == SP_ATTACHMENT_MESH || attachment->type == SP_ATTACHMENT_LINKED_MESH)
            worldCount = ((spMeshAttachment *)attachment)->super.worldVerticesLength;
        if (worldCount <= 0) { spSkeletonClipping_clipEnd(p->clipping, slot); continue; }
        if (worldCount > p->worldCapacity) {
            float *world = realloc(p->world, (size_t)worldCount * sizeof(float));
            if (!world) { spSkeletonClipping_clipEnd2(p->clipping); break; }
            p->world = world;
            p->worldCapacity = worldCount;
        }
        if (attachment->type == SP_ATTACHMENT_REGION) {
            spRegionAttachment *a = (spRegionAttachment *)attachment;
            spRegionAttachment_computeWorldVertices(a, slot, p->world, 0, 2);
            color = a->color; region = (spAtlasRegion *)a->region; uvs = a->uvs;
            indices = quadIndices; indexCount = 6;
        } else {
            spMeshAttachment *a = (spMeshAttachment *)attachment;
            spVertexAttachment_computeWorldVertices(&a->super, slot, 0, worldCount, p->world, 0, 2);
            color = a->color; region = (spAtlasRegion *)a->region; uvs = a->uvs;
            indices = a->triangles; indexCount = a->trianglesCount;
        }
        float *vertices = p->world;
        if (spSkeletonClipping_isClipping(p->clipping)) {
            spSkeletonClipping_clipTriangles(p->clipping, vertices, worldCount, indices, indexCount, uvs, 2);
            vertices = p->clipping->clippedVertices->items; worldCount = p->clipping->clippedVertices->size;
            uvs = p->clipping->clippedUVs->items;
            indices = p->clipping->clippedTriangles->items; indexCount = p->clipping->clippedTriangles->size;
        }
        if (region && indexCount > 0 && worldCount > 0) {
            spAtlasPage *page = region->page;
            int pageIndex = 0;
            for (spAtlasPage *candidate = p->atlas->pages; candidate && candidate != page; candidate = candidate->next) ++pageIndex;
            color.r *= slot->color.r * p->skeleton->color.r;
            color.g *= slot->color.g * p->skeleton->color.g;
            color.b *= slot->color.b * p->skeleton->color.b;
            color.a *= slot->color.a * p->skeleton->color.a;
            float darkScale = page->pma ? color.a : 1;
            float darkR = slot->darkColor ? slot->darkColor->r * darkScale : 0;
            float darkG = slot->darkColor ? slot->darkColor->g * darkScale : 0;
            float darkB = slot->darkColor ? slot->darkColor->b * darkScale : 0;
            if (page->pma) { color.r *= color.a; color.g *= color.a; color.b *= color.a; }
            OwnedDraw *owned = &p->draws[p->drawCount];
            if (owned->vertexCapacity < worldCount / 2) {
                AdaSpineVertex *buffer = realloc((void *)owned->draw.vertices, (size_t)(worldCount / 2) * sizeof(AdaSpineVertex));
                if (!buffer) { spSkeletonClipping_clipEnd2(p->clipping); break; }
                owned->draw.vertices = buffer;
                owned->vertexCapacity = worldCount / 2;
            }
            if (owned->indexCapacity < indexCount) {
                uint32_t *buffer = realloc((void *)owned->draw.indices, (size_t)indexCount * sizeof(uint32_t));
                if (!buffer) { spSkeletonClipping_clipEnd2(p->clipping); break; }
                owned->draw.indices = buffer;
                owned->indexCapacity = indexCount;
            }
            AdaSpineVertex *output = (AdaSpineVertex *)owned->draw.vertices;
            uint32_t *outputIndices = (uint32_t *)owned->draw.indices;
            for (int v = 0; v < worldCount / 2; ++v)
                output[v] = (AdaSpineVertex){vertices[v*2], vertices[v*2+1], uvs[v*2], uvs[v*2+1], color.r, color.g, color.b, color.a,
                                            darkR, darkG, darkB, page->pma ? 1.0f : 0.0f};
            for (int t = 0; t < indexCount; ++t) outputIndices[t] = indices[t];
            owned->draw = (AdaSpineDraw){pageIndex, slot->data->blendMode, page->pma, worldCount / 2, output, indexCount, outputIndices};
            ++p->drawCount;
        }
        spSkeletonClipping_clipEnd(p->clipping, slot);
    }
    spSkeletonClipping_clipEnd2(p->clipping);
    return p->drawCount;
}
AdaSpineDraw ada_spine_draw(AdaSpinePlayer *p, int i) { return p->draws[i].draw; }

int ada_spine_bone_count(const AdaSpinePlayer *p) { return p->skeleton->bonesCount; }
AdaSpineBone ada_spine_bone(const AdaSpinePlayer *p, int i) {
    const spBone *bone = p->skeleton->bones[i];
    return (AdaSpineBone){bone->data->name, bone->parent ? bone->parent->data->index : -1, bone->active,
                         bone->worldX, bone->worldY,
                         bone->worldX + bone->a * bone->data->length, bone->worldY + bone->c * bone->data->length};
}
