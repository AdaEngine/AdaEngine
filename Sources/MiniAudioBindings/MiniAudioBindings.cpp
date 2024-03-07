//
//  MiniAudioBindings.cpp.cpp
//  
//
//  Created by v.prusakov on 3/6/24.
//

#include "MiniAudioBindings.hpp"

namespace ma {
#define MA_IMPLEMENTATION
#include <miniaudio.h>
}

namespace ada {

ma_engine* ma_make_engine() {
    return (ma_engine*)new ma::ma_engine();
}

ma_result ma_engine_init(const ma_engine_config* pConfig, ma_engine* pEngine) {
    ma::ma_engine_config *config = new ma::ma_engine_config();
    config->channels = pConfig->channels;
    auto result = (ma_result)ma::ma_engine_init(config, (ma::ma_engine*)pEngine);
    return result;
}

void ma_engine_uninit(ma_engine* pEngine) {
    ma::ma_engine_uninit((ma::ma_engine *)pEngine);
}

ma_result ma_engine_start(ma_engine* pEngine) {
    return (ma_result)ma::ma_engine_start((ma::ma_engine *)pEngine);
}

ma_result ma_engine_stop(ma_engine* pEngine) {
    return (ma_result)ma::ma_engine_stop((ma::ma_engine *)pEngine);
}

//ma_result ma_engine_set_volume(ma_engine* pEngine, float volume);

ma_uint32 ma_engine_get_listener_count(const ma_engine* pEngine) {
    return ma::ma_engine_get_listener_count((ma::ma_engine *)pEngine);
}

ma_uint32 ma_engine_find_closest_listener(const ma_engine* pEngine, float absolutePosX, float absolutePosY, float absolutePosZ) {
    return ma::ma_engine_find_closest_listener((ma::ma_engine *)pEngine, absolutePosX, absolutePosY, absolutePosZ);
}

void ma_engine_listener_set_position(ma_engine* pEngine, ma_uint32 listenerIndex, float x, float y, float z) {
    ma::ma_engine_listener_set_position((ma::ma_engine *)pEngine, listenerIndex, x, y, z);
}

ma_vec3f ma_engine_listener_get_position(const ma_engine* pEngine, ma_uint32 listenerIndex) {
    ma::ma_vec3f vec = ma::ma_engine_listener_get_position((ma::ma_engine *)pEngine, listenerIndex);
    return (ma_vec3f){ vec.x, vec.y, vec.z };
}

void ma_engine_listener_set_direction(ma_engine* pEngine, ma_uint32 listenerIndex, float x, float y, float z) {
    return ma::ma_engine_listener_set_direction((ma::ma_engine *)pEngine, listenerIndex, x, y, z);
}

ma_vec3f ma_engine_listener_get_direction(const ma_engine* pEngine, ma_uint32 listenerIndex) {
    ma::ma_vec3f vec = ma::ma_engine_listener_get_direction((ma::ma_engine *)pEngine, listenerIndex);
    return (ma_vec3f){ vec.x, vec.y, vec.z };
}

void ma_engine_listener_set_velocity(ma_engine* pEngine, ma_uint32 listenerIndex, float x, float y, float z) {
    ma::ma_engine_listener_set_velocity((ma::ma_engine *)pEngine, listenerIndex, x, y, z);
}

ma_vec3f ma_engine_listener_get_velocity(const ma_engine* pEngine, ma_uint32 listenerIndex) {
    ma::ma_vec3f vec = ma::ma_engine_listener_get_velocity((ma::ma_engine *)pEngine, listenerIndex);
    return (ma_vec3f){ vec.x, vec.y, vec.z };
}

void ma_engine_listener_set_cone(ma_engine* pEngine, ma_uint32 listenerIndex, float innerAngleInRadians, float outerAngleInRadians, float outerGain) {
    ma::ma_engine_listener_set_cone((ma::ma_engine *)pEngine, listenerIndex, innerAngleInRadians, outerAngleInRadians, outerGain);
}

void ma_engine_listener_get_cone(const ma_engine* pEngine, ma_uint32 listenerIndex, float* pInnerAngleInRadians, float* pOuterAngleInRadians, float* pOuterGain) {
    ma::ma_engine_listener_get_cone((ma::ma_engine *)pEngine, listenerIndex, pInnerAngleInRadians, pOuterAngleInRadians, pOuterGain);
}

void ma_engine_listener_set_world_up(ma_engine* pEngine, ma_uint32 listenerIndex, float x, float y, float z) {
    ma::ma_engine_listener_set_world_up((ma::ma_engine *)pEngine, listenerIndex, x, y, z);
}

ma_vec3f ma_engine_listener_get_world_up(const ma_engine* pEngine, ma_uint32 listenerIndex) {
    ma::ma_vec3f vec = ma::ma_engine_listener_get_world_up((ma::ma_engine *)pEngine, listenerIndex);
    return (ma_vec3f){ vec.x, vec.y, vec.z };
}

void ma_engine_listener_set_enabled(ma_engine* pEngine, ma_uint32 listenerIndex, ma_bool32 isEnabled) {
    ma::ma_engine_listener_set_enabled((ma::ma_engine *)pEngine, listenerIndex, isEnabled);
}

ma_bool32 ma_engine_listener_is_enabled(const ma_engine* pEngine, ma_uint32 listenerIndex) {
    return ma::ma_engine_listener_is_enabled((ma::ma_engine *)pEngine, listenerIndex);
}


// MARK: Sound

ma_sound* ma_make_sound() {
    return (ma_sound*)new ma::ma_sound();
}

ma_result ma_sound_init_from_file(ma_engine* pEngine, const char* pFilePath, ma_uint32 flags, ma_sound_group* pGroup, ma_sound* pSound) {
    return (ma_result)ma::ma_sound_init_from_file((ma::ma_engine *)pEngine, pFilePath, flags, (ma::ma_sound_group *)pGroup, nullptr, (ma::ma_sound *)pSound);
}

ma_result ma_sound_init_from_data_source(ma_engine* pEngine, ma_data_source* pDataSource, ma_uint32 flags, ma_sound_group* pGroup, ma_sound* pSound) {
    return (ma_result)ma::ma_sound_init_from_data_source((ma::ma_engine *)pEngine, pDataSource, flags, (ma::ma_sound_group *)pGroup, (ma::ma_sound *)pSound);
}

ma_engine* ma_sound_get_engine(const ma_sound* pSound) {
    return (ma_engine *)ma::ma_sound_get_engine((ma::ma_sound *)pSound);
}

ma_result ma_sound_init_copy(ma_engine* pEngine, const ma_sound* pExistingSound, ma_uint32 flags, ma_sound_group* pGroup, ma_sound* pSound) {
    return (ma_result)ma::ma_sound_init_copy((ma::ma_engine *)pEngine, (ma::ma_sound *)pExistingSound, flags, (ma::ma_sound_group *)pGroup, (ma::ma_sound *)pSound);
}

void ma_sound_uninit(ma_sound* pSound) {
    ma::ma_sound_uninit((ma::ma_sound *)pSound);
}

ma_result ma_sound_start(ma_sound* pSound) {
    return (ma_result)ma::ma_sound_start((ma::ma_sound *)pSound);
}

ma_result ma_sound_stop(ma_sound* pSound) {
    return (ma_result)ma::ma_sound_stop((ma::ma_sound *)pSound);
}

void ma_sound_set_volume(ma_sound* pSound, float volume) {
    ma::ma_sound_set_volume((ma::ma_sound *)pSound, volume);
}

float ma_sound_get_volume(const ma_sound* pSound) {
    return ma::ma_sound_get_volume((ma::ma_sound *)pSound);
}

void ma_sound_set_pitch(ma_sound* pSound, float pitch) {
    ma::ma_sound_set_pitch((ma::ma_sound *)pSound, pitch);
}

float ma_sound_get_pitch(const ma_sound* pSound) {
    return ma::ma_sound_get_pitch((ma::ma_sound *)pSound);
}

void ma_sound_set_looping(ma_sound* pSound, ma_bool32 isLooping) {
    return ma::ma_sound_set_looping((ma::ma_sound *)pSound, isLooping);
}

ma_bool32 ma_sound_is_looping(const ma_sound* pSound) {
    return ma::ma_sound_is_looping((ma::ma_sound *)pSound);
}

ma_bool32 ma_sound_is_playing(const ma_sound* pSound) {
    return ma::ma_sound_is_playing((ma::ma_sound *)pSound);
}

ma_result ma_sound_set_end_callback(ma_sound* pSound, ma_sound_end_proc callback, void* pUserData) {
    return (ma_result)ma::ma_sound_set_end_callback((ma::ma_sound *)pSound, (ma::ma_sound_end_proc)callback, pUserData);
}

ma_result ma_sound_seek_to_pcm_frame(ma_sound* pSound, ma_uint64 frameIndex) {
    return (ma_result)ma::ma_sound_seek_to_pcm_frame((ma::ma_sound *)pSound, frameIndex);
}

void ma_sound_set_position(ma_sound* pSound, float x, float y, float z) {
    ma::ma_sound_set_position((ma::ma_sound *)pSound, x, y, z);
}

ma_vec3f ma_sound_get_position(const ma_sound* pSound) {
    ma::ma_vec3f vec = ma::ma_sound_get_position((ma::ma_sound *)pSound);

    return (ma_vec3f){ vec.x, vec.y, vec.z };
}

}
