// Morph targets (glTF blend shapes) applied to a vertex before skinning.
//
// Compiled in only for draws of morphed meshes, which define ADA_MORPH; otherwise this file declares nothing. The deltas of
// the few active targets are fetched from a half-float texture (see MorphTargetSet), so the cost depends on the number of
// active targets, not the number of targets the mesh has.
#ifdef ADA_MORPH
layout (binding = 21) uniform Morph3DUniform {
    vec4 u_MorphCounts;      // x active targets, y previous frame's active targets, z vertices per target, w attributes per vertex
    vec4 u_MorphFlags;       // x bit 0: normal deltas present, bit 1: tangent deltas present
    vec4 u_MorphCurrent[8];  // x target index, y weight
    vec4 u_MorphPrevious[8]; // the previous frame's, for motion vectors
};
layout (binding = 40) uniform texture2D u_MorphDeltas;

const int MORPH_TEXTURE_WIDTH = 2048;

vec3 morphDelta(int morphTarget, int channel) {
    int texel = (morphTarget * int(u_MorphCounts.z) + gl_VertexIndex) * int(u_MorphCounts.w) + channel;
    return texelFetch(u_MorphDeltas, ivec2(texel % MORPH_TEXTURE_WIDTH, texel / MORPH_TEXTURE_WIDTH), 0).xyz;
}

// Adds the weighted position deltas of the active targets.
void applyMorphPosition(inout vec3 position) {
    for (int i = 0; i < 8; ++i) {
        if (i >= int(u_MorphCounts.x)) { break; }
        position += morphDelta(int(u_MorphCurrent[i].x), 0) * u_MorphCurrent[i].y;
    }
}

// The same for the previous frame's weights.
vec3 previousMorphedPosition(vec3 position) {
    for (int i = 0; i < 8; ++i) {
        if (i >= int(u_MorphCounts.y)) { break; }
        position += morphDelta(int(u_MorphPrevious[i].x), 0) * u_MorphPrevious[i].y;
    }
    return position;
}

// Adds the weighted position, normal and tangent deltas of the active targets.
void applyMorph(inout vec3 position, inout vec3 normal, inout vec3 tangent) {
    int flags = int(u_MorphFlags.x);
    bool hasNormals = (flags & 1) != 0;
    bool hasTangents = (flags & 2) != 0;
    int tangentChannel = hasNormals ? 2 : 1;
    for (int i = 0; i < 8; ++i) {
        if (i >= int(u_MorphCounts.x)) { break; }
        int morphTarget = int(u_MorphCurrent[i].x);
        float weight = u_MorphCurrent[i].y;
        position += morphDelta(morphTarget, 0) * weight;
        if (hasNormals) { normal += morphDelta(morphTarget, 1) * weight; }
        if (hasTangents) { tangent += morphDelta(morphTarget, tangentChannel) * weight; }
    }
}
#endif
