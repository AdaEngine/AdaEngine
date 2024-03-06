
/// DISCLAMER:
///
///     All the time when I wrote this engine, I do this fucking "binding" things
///     This orange bird is fucking awful. Why they cannot create BASIC C++ compatibility??
///     In previous itterations of exprimental C++ interop, this code did work correctly, but a "brand new C++ interop"
///     destroy everything...
///     I hope, in the future releases I will delete this shit and use FULL PATENCIAL of this lib...
///
///     But for now, I will fuck my life and write this stupid bridging for stupid Swift. FUCK!
///

// MARK: Common

namespace ada {

/* Sized types. */
#if defined(MA_USE_STDINT)
#include <stdint.h>
typedef int8_t   ma_int8;
typedef uint8_t  ma_uint8;
typedef int16_t  ma_int16;
typedef uint16_t ma_uint16;
typedef int32_t  ma_int32;
typedef uint32_t ma_uint32;
typedef int64_t  ma_int64;
typedef uint64_t ma_uint64;
#else
typedef   signed char           ma_int8;
typedef unsigned char           ma_uint8;
typedef   signed short          ma_int16;
typedef unsigned short          ma_uint16;
typedef   signed int            ma_int32;
typedef unsigned int            ma_uint32;
#if defined(_MSC_VER) && !defined(__clang__)
typedef   signed __int64    ma_int64;
typedef unsigned __int64    ma_uint64;
#else
#if defined(__clang__) || (defined(__GNUC__) && (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 6)))
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wlong-long"
#if defined(__clang__)
#pragma GCC diagnostic ignored "-Wc++11-long-long"
#endif
#endif
typedef   signed long long  ma_int64;
typedef unsigned long long  ma_uint64;
#if defined(__clang__) || (defined(__GNUC__) && (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 6)))
#pragma GCC diagnostic pop
#endif
#endif
#endif  /* MA_USE_STDINT */

#if MA_SIZEOF_PTR == 8
typedef ma_uint64           ma_uintptr;
#else
typedef ma_uint32           ma_uintptr;
#endif

typedef ma_uint8    ma_bool8;
typedef ma_uint32   ma_bool32;
#define MA_TRUE     1
#define MA_FALSE    0

/* These float types are not used universally by miniaudio. It's to simplify some macro expansion for atomic types. */
typedef float       ma_float;
typedef double      ma_double;

typedef void* ma_handle;

/* Spatializer. */
typedef struct
{
    float x;
    float y;
    float z;
} ma_vec3f;

typedef enum
{
    MA_SUCCESS                        =  0,
    MA_ERROR                          = -1,  /* A generic error. */
    MA_INVALID_ARGS                   = -2,
    MA_INVALID_OPERATION              = -3,
    MA_OUT_OF_MEMORY                  = -4,
    MA_OUT_OF_RANGE                   = -5,
    MA_ACCESS_DENIED                  = -6,
    MA_DOES_NOT_EXIST                 = -7,
    MA_ALREADY_EXISTS                 = -8,
    MA_TOO_MANY_OPEN_FILES            = -9,
    MA_INVALID_FILE                   = -10,
    MA_TOO_BIG                        = -11,
    MA_PATH_TOO_LONG                  = -12,
    MA_NAME_TOO_LONG                  = -13,
    MA_NOT_DIRECTORY                  = -14,
    MA_IS_DIRECTORY                   = -15,
    MA_DIRECTORY_NOT_EMPTY            = -16,
    MA_AT_END                         = -17,
    MA_NO_SPACE                       = -18,
    MA_BUSY                           = -19,
    MA_IO_ERROR                       = -20,
    MA_INTERRUPT                      = -21,
    MA_UNAVAILABLE                    = -22,
    MA_ALREADY_IN_USE                 = -23,
    MA_BAD_ADDRESS                    = -24,
    MA_BAD_SEEK                       = -25,
    MA_BAD_PIPE                       = -26,
    MA_DEADLOCK                       = -27,
    MA_TOO_MANY_LINKS                 = -28,
    MA_NOT_IMPLEMENTED                = -29,
    MA_NO_MESSAGE                     = -30,
    MA_BAD_MESSAGE                    = -31,
    MA_NO_DATA_AVAILABLE              = -32,
    MA_INVALID_DATA                   = -33,
    MA_TIMEOUT                        = -34,
    MA_NO_NETWORK                     = -35,
    MA_NOT_UNIQUE                     = -36,
    MA_NOT_SOCKET                     = -37,
    MA_NO_ADDRESS                     = -38,
    MA_BAD_PROTOCOL                   = -39,
    MA_PROTOCOL_UNAVAILABLE           = -40,
    MA_PROTOCOL_NOT_SUPPORTED         = -41,
    MA_PROTOCOL_FAMILY_NOT_SUPPORTED  = -42,
    MA_ADDRESS_FAMILY_NOT_SUPPORTED   = -43,
    MA_SOCKET_NOT_SUPPORTED           = -44,
    MA_CONNECTION_RESET               = -45,
    MA_ALREADY_CONNECTED              = -46,
    MA_NOT_CONNECTED                  = -47,
    MA_CONNECTION_REFUSED             = -48,
    MA_NO_HOST                        = -49,
    MA_IN_PROGRESS                    = -50,
    MA_CANCELLED                      = -51,
    MA_MEMORY_ALREADY_MAPPED          = -52,

    /* General miniaudio-specific errors. */
    MA_FORMAT_NOT_SUPPORTED           = -100,
    MA_DEVICE_TYPE_NOT_SUPPORTED      = -101,
    MA_SHARE_MODE_NOT_SUPPORTED       = -102,
    MA_NO_BACKEND                     = -103,
    MA_NO_DEVICE                      = -104,
    MA_API_NOT_FOUND                  = -105,
    MA_INVALID_DEVICE_CONFIG          = -106,
    MA_LOOP                           = -107,
    MA_BACKEND_NOT_ENABLED            = -108,

    /* State errors. */
    MA_DEVICE_NOT_INITIALIZED         = -200,
    MA_DEVICE_ALREADY_INITIALIZED     = -201,
    MA_DEVICE_NOT_STARTED             = -202,
    MA_DEVICE_NOT_STOPPED             = -203,

    /* Operation errors. */
    MA_FAILED_TO_INIT_BACKEND         = -300,
    MA_FAILED_TO_OPEN_BACKEND_DEVICE  = -301,
    MA_FAILED_TO_START_BACKEND_DEVICE = -302,
    MA_FAILED_TO_STOP_BACKEND_DEVICE  = -303
} ma_result;

/* Sound flags. */
typedef enum
{
    /* Resource manager flags. */
    MA_SOUND_FLAG_STREAM                = 0x00000001,   /* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_STREAM */
    MA_SOUND_FLAG_DECODE                = 0x00000002,   /* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_DECODE */
    MA_SOUND_FLAG_ASYNC                 = 0x00000004,   /* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_ASYNC */
    MA_SOUND_FLAG_WAIT_INIT             = 0x00000008,   /* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_WAIT_INIT */
    MA_SOUND_FLAG_UNKNOWN_LENGTH        = 0x00000010,   /* MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_UNKNOWN_LENGTH */

    /* ma_sound specific flags. */
    MA_SOUND_FLAG_NO_DEFAULT_ATTACHMENT = 0x00001000,   /* Do not attach to the endpoint by default. Useful for when setting up nodes in a complex graph system. */
    MA_SOUND_FLAG_NO_PITCH              = 0x00002000,   /* Disable pitch shifting with ma_sound_set_pitch() and ma_sound_group_set_pitch(). This is an optimization. */
    MA_SOUND_FLAG_NO_SPATIALIZATION     = 0x00004000    /* Disable spatialization. */
} ma_sound_flags;

// MARK: - Bindings

typedef struct
{
    //#if !defined(MA_NO_RESOURCE_MANAGER)
    //    ma_resource_manager* pResourceManager;          /* Can be null in which case a resource manager will be created for you. */
    //#endif
    //#if !defined(MA_NO_DEVICE_IO)
    //    ma_context* pContext;
    //    ma_device* pDevice;                             /* If set, the caller is responsible for calling ma_engine_data_callback() in the device's data callback. */
    //    ma_device_id* pPlaybackDeviceID;                /* The ID of the playback device to use with the default listener. */
    //    ma_device_notification_proc notificationCallback;
    //#endif
    //    ma_log* pLog;                                   /* When set to NULL, will use the context's log. */
    ma_uint32 listenerCount;                        /* Must be between 1 and MA_ENGINE_MAX_LISTENERS. */
    ma_uint32 channels;                             /* The number of channels to use when mixing and spatializing. When set to 0, will use the native channel count of the device. */
    ma_uint32 sampleRate;                           /* The sample rate. When set to 0 will use the native channel count of the device. */
    ma_uint32 periodSizeInFrames;                   /* If set to something other than 0, updates will always be exactly this size. The underlying device may be a different size, but from the perspective of the mixer that won't matter.*/
    ma_uint32 periodSizeInMilliseconds;             /* Used if periodSizeInFrames is unset. */
    ma_uint32 gainSmoothTimeInFrames;               /* The number of frames to interpolate the gain of spatialized sounds across. If set to 0, will use gainSmoothTimeInMilliseconds. */
    ma_uint32 gainSmoothTimeInMilliseconds;         /* When set to 0, gainSmoothTimeInFrames will be used. If both are set to 0, a default value will be used. */
    ma_uint32 defaultVolumeSmoothTimeInPCMFrames;   /* Defaults to 0. Controls the default amount of smoothing to apply to volume changes to sounds. High values means more smoothing at the expense of high latency (will take longer to reach the new volume). */
    //    ma_allocation_callbacks allocationCallbacks;
    ma_bool32 noAutoStart;                          /* When set to true, requires an explicit call to ma_engine_start(). This is false by default, meaning the engine will be started automatically in ma_engine_init(). */
    ma_bool32 noDevice;                             /* When set to true, don't create a default device. ma_engine_read_pcm_frames() can be called manually to read data. */
    //    ma_mono_expansion_mode monoExpansionMode;       /* Controls how the mono channel should be expanded to other channels when spatialization is disabled on a sound. */
    //    ma_vfs* pResourceManagerVFS;                    /* A pointer to a pre-allocated VFS object to use with the resource manager. This is ignored if pResourceManager is not NULL. */
} ma_engine_config;

typedef struct ma_engine ma_engine;
typedef struct ma_sound  ma_sound;

// MARK: Engine

ma_engine* ma_make_engine();

ma_result ma_engine_init(const ma_engine_config* pConfig, ma_engine* pEngine);
void ma_engine_uninit(ma_engine* pEngine);
ma_result ma_engine_start(ma_engine* pEngine);
ma_result ma_engine_stop(ma_engine* pEngine);
//ma_result ma_engine_set_volume(ma_engine* pEngine, float volume);

ma_uint32 ma_engine_get_listener_count(const ma_engine* pEngine);
ma_uint32 ma_engine_find_closest_listener(const ma_engine* pEngine, float absolutePosX, float absolutePosY, float absolutePosZ);
void ma_engine_listener_set_position(ma_engine* pEngine, ma_uint32 listenerIndex, float x, float y, float z);
ma_vec3f ma_engine_listener_get_position(const ma_engine* pEngine, ma_uint32 listenerIndex);
void ma_engine_listener_set_direction(ma_engine* pEngine, ma_uint32 listenerIndex, float x, float y, float z);
ma_vec3f ma_engine_listener_get_direction(const ma_engine* pEngine, ma_uint32 listenerIndex);
void ma_engine_listener_set_velocity(ma_engine* pEngine, ma_uint32 listenerIndex, float x, float y, float z);
ma_vec3f ma_engine_listener_get_velocity(const ma_engine* pEngine, ma_uint32 listenerIndex);
void ma_engine_listener_set_cone(ma_engine* pEngine, ma_uint32 listenerIndex, float innerAngleInRadians, float outerAngleInRadians, float outerGain);
void ma_engine_listener_get_cone(const ma_engine* pEngine, ma_uint32 listenerIndex, float* pInnerAngleInRadians, float* pOuterAngleInRadians, float* pOuterGain);
void ma_engine_listener_set_world_up(ma_engine* pEngine, ma_uint32 listenerIndex, float x, float y, float z);
ma_vec3f ma_engine_listener_get_world_up(const ma_engine* pEngine, ma_uint32 listenerIndex);
void ma_engine_listener_set_enabled(ma_engine* pEngine, ma_uint32 listenerIndex, ma_bool32 isEnabled);
ma_bool32 ma_engine_listener_is_enabled(const ma_engine* pEngine, ma_uint32 listenerIndex);

// MARK: Sound

ma_sound* ma_make_sound();

typedef void ma_data_source;
typedef ma_sound        ma_sound_group;

/* Callback for when a sound reaches the end. */
typedef void (* ma_sound_end_proc)(void* pUserData, ma_sound* pSound);

ma_result ma_sound_init_from_file(ma_engine* pEngine, const char* pFilePath, ma_uint32 flags, ma_sound_group* pGroup, ma_sound* pSound);
ma_result ma_sound_init_from_data_source(ma_engine* pEngine, ma_data_source* pDataSource, ma_uint32 flags, ma_sound_group* pGroup, ma_sound* pSound);
ma_engine* ma_sound_get_engine(const ma_sound* pSound);
ma_result ma_sound_init_copy(ma_engine* pEngine, const ma_sound* pExistingSound, ma_uint32 flags, ma_sound_group* pGroup, ma_sound* pSound);
void ma_sound_uninit(ma_sound* pSound);
ma_result ma_sound_start(ma_sound* pSound);
ma_result ma_sound_stop(ma_sound* pSound);
void ma_sound_set_volume(ma_sound* pSound, float volume);
float ma_sound_get_volume(const ma_sound* pSound);
void ma_sound_set_pitch(ma_sound* pSound, float pitch);
float ma_sound_get_pitch(const ma_sound* pSound);
void ma_sound_set_looping(ma_sound* pSound, ma_bool32 isLooping);
ma_bool32 ma_sound_is_looping(const ma_sound* pSound);
ma_bool32 ma_sound_is_playing(const ma_sound* pSound);
ma_result ma_sound_set_end_callback(ma_sound* pSound, ma_sound_end_proc callback, void* pUserData);
ma_result ma_sound_seek_to_pcm_frame(ma_sound* pSound, ma_uint64 frameIndex); /* Just a wrapper around ma_data_source_seek_to_pcm_frame(). */
void ma_sound_set_position(ma_sound* pSound, float x, float y, float z);
ma_vec3f ma_sound_get_position(const ma_sound* pSound);

}
