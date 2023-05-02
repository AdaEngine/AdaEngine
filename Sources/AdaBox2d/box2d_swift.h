//
//  box2d_swift.h
//  AdaEngine
//
//  Created by v.prusakov on 3/14/23.
//

#ifndef BOX2D_SWIFT_h
#define BOX2D_SWIFT_h

#include <stdint.h>

struct b2_vec2 {
    float x;
    float y;
};

// MARK: B2_SHAPE

typedef struct b2_shape_s b2_shape_t;

// MARK: B2_BODY

typedef struct b2_mass_data {
    float mass;
    b2_vec2 center;
    float I;
} b2_mass_data;

typedef enum b2_body_type {
    B2_BODY_TYPE_DYNAMIC = 0,
    B2_BODY_TYPE_STATIC = 1,
    B2_BODY_TYPE_KINEMATIC = 2,
} b2_body_type;

typedef enum b2_shape_type {
    B2_SHAPE_TYPE_CIRCLE = 0,
    B2_SHAPE_TYPE_EDGE = 1,
    B2_SHAPE_TYPE_POLYGON = 2,
    B2_SHAPE_TYPE_CHAIN = 3,
    B2_SHAPE_TYPE_COUNT = 4
} b2_shape_type;

typedef struct b2_fixture_def {
    const void *shape;
    float friction;
    float restitution;
    float restitutionThreshold;
    float density;
    bool isSensor;
} b2_fixture_def;

typedef struct b2_body_def {
    b2_body_type type;
    float angle;
    b2_vec2 position;
    b2_vec2 linearVelocity;
    float angularVelocity;
    float linearDamping;
    float angularDamping;
    bool allowSleep;
    bool awake;
    bool fixedRotation;
    bool bullet;
    bool enabled;

    float gravityScale;
} b2_body_def;

typedef struct b2_body_s b2_body_t;

typedef struct contact_listener_s contact_listener_t;

typedef struct b2_contact_s b2_contact_t;
typedef struct b2_manifold_s b2_manifold_t;
typedef struct b2_contact_impulse_s b2_contact_impulse_t;

// MARK: B2_FIXTURE

typedef struct b2_fixture_s b2_fixture_t;
typedef struct b2_fixture_def_s b2_fixture_def_t;

typedef struct b2_filter {
    uint16_t categoryBits;

    uint16_t maskBits;

    int16_t groupIndex;
} b2_filter;

// MARK: B2_WORLD

typedef struct b2_world_s b2_world_t;

// MARK: B2_CONTACT_LISTENER

typedef void (*contact_listener_begin_contact_func)(const void* userData, b2_contact_s* contact);
typedef void (*contact_listener_end_contact_func)(const void* userData, b2_contact_s* contact);
typedef void (*contact_listener_presolve_func)(const void* userData, b2_contact_s* contact, b2_manifold_s* oldManifold);
typedef void (*contact_listener_postsolve_func)(const void* userData, b2_contact_s* contact, b2_contact_impulse_s* impulse);

typedef struct contact_listener_callbacks {
    contact_listener_begin_contact_func begin_contact;
    contact_listener_end_contact_func end_contact;
    contact_listener_presolve_func pre_solve;
    contact_listener_postsolve_func post_solve;
} contact_listener_callbacks;

typedef float (*raycast_listener_reportfixture_func)(const void* userData, b2_fixture_s* fixture, b2_vec2 point, b2_vec2 normal, float fraction);

typedef struct raycast_listener_callback {
    raycast_listener_reportfixture_func report_fixture;
} raycast_listener_callback;

#ifdef __cplusplus
extern "C" {
#endif

// MARK: B2_WORLD

void b2_world_destroy(b2_world_s* world);
b2_world_s* b2_world_create(b2_vec2 gravity);

void b2_world_step(b2_world_s* world,
                   float timeStep,
                   signed int velocityIterations,
                   signed int positionIterations);

b2_vec2 b2_world_get_gravity(b2_world_s* world);
void b2_world_set_gravity(b2_world_s* world, b2_vec2 gravity);
void b2_world_set_contact_listener(b2_world_s* world, contact_listener_s* listener);

void b2_world_clear_forces(b2_world_s* world);
void b2_world_raycast(b2_world_s* world, b2_vec2 origin, b2_vec2 dist, const void *userData, raycast_listener_callback callbacks);

b2_body_s* b2_world_create_body(b2_world_s* world, b2_body_def bodyDef);
void b2_world_destroy_body(b2_world_s* world, b2_body_s* body);

// MARK: B2_BODY

b2_vec2 b2_body_get_position(b2_body_s* body);
float b2_body_get_angle(b2_body_s* body);
b2_vec2 b2_body_get_linear_velocity(b2_body_s* body);
b2_vec2 b2_body_get_world_center(b2_body_s* body);

void b2_body_set_transform(b2_body_s* body, b2_vec2 position, float angle);
void b2_body_set_linear_velocity(b2_body_s* body, b2_vec2 vector);

void b2_body_apply_force(b2_body_s* body, b2_vec2 force, b2_vec2 point, bool wake);
void b2_body_apply_force_to_center(b2_body_s* body, b2_vec2 force, bool wake);

void b2_body_apply_linear_impulse(b2_body_s* body, b2_vec2 impulse, b2_vec2 point, bool wake);
void b2_body_apply_torque(b2_body_s* body, float torque, bool wake);

b2_vec2 b2_body_get_linear_velocity_from_world_point(b2_body_s* body, b2_vec2 worldPoint);
b2_vec2 b2_body_get_linear_velocity_from_local_point(b2_body_s* body, b2_vec2 localPoint);

void b2_body_create_fixture(b2_body_s* body, b2_fixture_def def);

void b2_body_set_user_data(b2_body_s* body, const void* userData);
const void* b2_body_get_user_data(b2_body_s* body);

b2_fixture_s* b2_body_get_fixture_list(b2_body_s* body);

b2_mass_data b2_body_get_mass_data(b2_body_s* body);
void b2_body_set_mass_data(b2_body_s* body, b2_mass_data massData);

// MARK: B2_FIXTURE

b2_filter b2_fixture_get_filter_data(b2_fixture_s* fixture);
void b2_fixture_set_filter_data(b2_fixture_s* fixture, b2_filter filterData);

b2_body_s* b2_fixture_get_body(b2_fixture_s* fixture);

b2_shape_type b2_fixture_get_type(b2_fixture_s* fixture);
b2_shape_s* b2_fixture_get_shape(b2_fixture_s* fixture);

// MARK: B2_SHAPE

b2_shape_s* b2_create_polygon_shape();
b2_shape_s* b2_create_circle_shape();
void b2_shape_set_radius(b2_shape_s* shape, float radius);
float b2_shape_get_radius(b2_shape_s* shape);

void b2_circle_shape_set_position(b2_shape_s* shape, b2_vec2 position);

void b2_polygon_shape_set(b2_shape_s* polygonShape, const b2_vec2* points, signed int count);
void b2_polygon_shape_set_as_box(b2_shape_s* polygonShape, float halfWidth, float halfHeight);
void b2_polygon_shape_set_as_box_with_center(b2_shape_s* polygonShape,
                                             float halfWidth,
                                             float halfHeight,
                                             b2_vec2 center,
                                             float angle);

b2_shape_type b2_shape_get_type(b2_shape_s* shape);

void b2_polygon_shape_get_vertices(b2_shape_s* polyginShape, b2_vec2** vertices, uint32_t* count);

// MARK: B2_CONTACT_LISTENER

contact_listener_s* b2_create_contactListener(const void *userData, contact_listener_callbacks callbacks);

b2_fixture_s* b2_contact_get_fixture_a(b2_contact_s *contact);
b2_fixture_s* b2_contact_get_fixture_b(b2_contact_s *contact);
b2_manifold_s* b2_contact_get_manifold(b2_contact_s *contact);

// b2ContactListner end

#ifdef __cplusplus
}
#endif

#endif /* BOX2D_SWIFT_h */
