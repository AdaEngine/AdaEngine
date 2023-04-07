//
//  box2d_swift.c
//  
//
//  Created by v.prusakov on 3/14/23.
//

#include "box2d_swift.h"
#include <box2d/box2d.h>
#include <memory>

// MARK: B2_SHAPE

typedef struct b2_shape_s {
    b2Shape *shape;
} b2_shape_t;

// MARK: B2_FIXTURE

typedef struct b2_fixture_s {
    b2Fixture *fixture;
} b2_fixture_t;

// MARK: B2_BODY

typedef struct b2_body_s {
    b2Body *body;
} b2_body_t;

// MARK: B2_WORLD

typedef struct b2_world_s {
    b2World *world;
} b2_world_t;

typedef struct contact_listener_s {
    b2ContactListener* listener;
} contact_listener_t;

typedef struct b2_contact_s {
    b2Contact *contact;
} b2_contact_t;

typedef struct b2_manifold_s {
    const b2Manifold *manifold;
} b2_manifold_t;

typedef struct b2_contact_impulse_s {
    const b2ContactImpulse *impulse;
} b2_contact_impulse_t;

// MARK: - Functions

b2_world_s* b2_world_create(b2_vec2 gravity) {
    b2Vec2 vec(gravity.x, gravity.y);
    b2World *world = new b2World(vec);
    b2_world_s *c_world = new b2_world_s();
    c_world->world = world;
    return c_world;
}

void b2_world_destroy(b2_world_s* world) {
    delete world->world;
    delete world;
}

void b2_world_step(b2_world_s* world, float timeStep, signed int velocityIterations, signed int positionIterations) {
    world->world->Step(timeStep, velocityIterations, positionIterations);
}

b2_vec2 b2_world_get_gravity(b2_world_s* world) {
    b2Vec2 gravity = world->world->GetGravity();
    return { gravity.x, gravity.y };
}

void b2_world_set_gravity(b2_world_s* world, b2_vec2 gravity) {
    b2Vec2 vector(gravity.x, gravity.y);
    world->world->SetGravity(vector);
}

void b2_world_set_contact_listener(b2_world_s* world, contact_listener_s* contact_listener) {
    world->world->SetContactListener(contact_listener->listener);
}

b2_body_s* b2_world_create_body(b2_world_s* world, b2_body_def bodyDef) {
    b2BodyDef def;
    def.angle = bodyDef.angle;
    def.position = { bodyDef.position.x, bodyDef.position.y };
    
    switch (bodyDef.type) {
        case B2_BODY_TYPE_STATIC:
            def.type = b2_staticBody;
            break;
        case B2_BODY_TYPE_DYNAMIC:
            def.type = b2_dynamicBody;
            break;
        case B2_BODY_TYPE_KINEMATIC:
            def.type = b2_kinematicBody;
            break;
    }
    def.gravityScale = bodyDef.gravityScale;
    def.allowSleep = bodyDef.allowSleep;
    def.fixedRotation = bodyDef.fixedRotation;
    def.bullet = bodyDef.bullet;
    def.awake = bodyDef.awake;
    def.angularDamping = bodyDef.angularDamping;
    def.angularVelocity = bodyDef.angularVelocity;
    def.linearDamping = bodyDef.linearDamping;
    def.linearVelocity = { bodyDef.linearVelocity.x, bodyDef.linearVelocity.y };
    
    b2Body *body = world->world->CreateBody(&def);
    b2_body_s *c_body = new b2_body_s();
    c_body->body = body;
    return c_body;
}

void b2_world_destroy_body(b2_world_s* world, b2_body_s* body) {
    world->world->DestroyBody(body->body);
}

void b2_world_clear_forces(b2_world_s* world) {
    world->world->ClearForces();
}

// MARK: B2_RAYCASTLISTENER

class RayCastCallback: public b2RayCastCallback {
public:
    RayCastCallback(const void *userData, raycast_listener_callback callbacks): m_UserData(userData), m_ReportFixture(callbacks.report_fixture) {}
    
    virtual float ReportFixture(b2Fixture* fixture, const b2Vec2& point, const b2Vec2& normal, float fraction) override {
        if (m_ReportFixture) {
            b2_fixture_s* fixture_s = new b2_fixture_s();
            fixture_s->fixture = fixture;
            
            float result = m_ReportFixture(m_UserData, fixture_s, { point.x, point.y }, { normal.x, normal.y }, fraction);
            
            // delete fixture after usage
            delete fixture_s;
            
            return result;
        }
        
        // terminate raycast if m_ReportFixture is null
        return 0.0f;
    }
    
private:
    const void* m_UserData;
    raycast_listener_reportfixture_func m_ReportFixture;
};

void b2_world_raycast(b2_world_s* world, b2_vec2 origin, b2_vec2 dist, const void *userData, raycast_listener_callback callbacks) {
    b2RayCastCallback *callback = new RayCastCallback(userData, callbacks);
    world->world->RayCast(callback, { origin.x, origin.y }, { dist.x, dist.y });
    delete callback;
}

// MARK: B2_BODY

b2_vec2 b2_body_get_position(b2_body_s* body) {
    b2Vec2 position = body->body->GetPosition();
    return { position.x, position.y };
}

float b2_body_get_angle(b2_body_s* body) {
    return body->body->GetAngle();
}

b2_vec2 b2_body_get_linear_velocity(b2_body_s* body) {
    b2Vec2 vec = body->body->GetLinearVelocity();
    return { vec.x, vec.y };
}

b2_vec2 b2_body_get_world_center(b2_body_s* body) {
    b2Vec2 vec = body->body->GetWorldCenter();
    return { vec.x, vec.y };
}

void b2_body_set_transform(b2_body_s* body, b2_vec2 position, float angle) {
    b2Vec2 pos = { position.x, position.y };
    body->body->SetTransform(pos, angle);
}

void b2_body_set_linear_velocity(b2_body_s* body, b2_vec2 vector) {
    body->body->SetLinearVelocity({ vector.x, vector.y });
}

void b2_body_apply_force(b2_body_s* body, b2_vec2 force, b2_vec2 point, bool wake) {
    body->body->ApplyForce({ force.x, force.x }, { point.x, point.y }, wake);
}

void b2_body_apply_force_to_center(b2_body_s* body, b2_vec2 force, bool wake) {
    body->body->ApplyForceToCenter({ force.x, force.x }, wake);
}

void b2_body_apply_linear_impulse(b2_body_s* body, b2_vec2 impulse, b2_vec2 point, bool wake) {
    body->body->ApplyLinearImpulse({ impulse.x, impulse.y }, { point.x, point.y }, wake);
}

void b2_body_apply_torque(b2_body_s* body, float torque, bool wake) {
    body->body->ApplyTorque(torque, wake);
}

b2_vec2 b2_body_get_linear_velocity_from_world_point(b2_body_s* body, b2_vec2 worldPoint) {
    b2Vec2 vec = body->body->GetLinearVelocityFromWorldPoint({ worldPoint.x, worldPoint.y });
    return { vec.x, vec.y };
}

b2_vec2 b2_body_get_linear_velocity_from_local_point(b2_body_s* body, b2_vec2 localPoint) {
    b2Vec2 vec = body->body->GetLinearVelocityFromLocalPoint({ localPoint.x, localPoint.y });
    return { vec.x, vec.y };
}

b2_mass_data b2_body_get_mass_data(b2_body_s* body) {
    auto massData = body->body->GetMassData();
    b2_mass_data data;
    data.center = { massData.center.x, massData.center.y };
    data.mass = massData.mass;
    data.I = massData.I;
    return data;
}

void b2_body_set_mass_data(b2_body_s* body, b2_mass_data massData) {
    auto data = body->body->GetMassData();
    data.center = { massData.center.x, massData.center.y };
    data.mass = massData.mass;
    data.I = massData.I;
    body->body->SetMassData(&data);
}

b2_fixture_s* b2_body_get_fixture_list(b2_body_s* body) {
    auto b2Fixture = body->body->GetFixtureList();
    b2_fixture_s *fixture = new b2_fixture_s();
    fixture->fixture = b2Fixture;
    return fixture;
}

void b2_body_create_fixture(b2_body_s* body, b2_fixture_def def) {
    b2FixtureDef fixtureDef;
    fixtureDef.restitutionThreshold = def.restitutionThreshold;
    fixtureDef.density = def.density;
    fixtureDef.friction = def.friction;
    fixtureDef.shape = ((b2_shape_s *)def.shape)->shape;
    fixtureDef.isSensor = def.isSensor;
    fixtureDef.restitution = def.restitution;
    body->body->CreateFixture(&fixtureDef);
}

void b2_body_set_user_data(b2_body_s* body, const void* userData) {
    body->body->GetUserData().pointer = (uintptr_t)userData;
}

const void* b2_body_get_user_data(b2_body_s* body) {
    const b2BodyUserData& b2UserData = body->body->GetUserData();
    return (const void *)b2UserData.pointer;
}

// MARK: B2_FIXTURE

b2_filter b2_fixture_get_filter_data(b2_fixture_s* fixture) {
    auto b2Filter = fixture->fixture->GetFilterData();
    
    b2_filter filter;
    filter.categoryBits = b2Filter.categoryBits;
    filter.groupIndex = b2Filter.groupIndex;
    filter.maskBits = b2Filter.maskBits;
    return filter;
}

void b2_fixture_set_filter_data(b2_fixture_s* fixture, b2_filter filterData) {
    auto b2Filter = fixture->fixture->GetFilterData();
    b2Filter.categoryBits = filterData.categoryBits;
    b2Filter.groupIndex = filterData.groupIndex;
    b2Filter.maskBits = filterData.maskBits;
    
    fixture->fixture->SetFilterData(b2Filter);
}

b2_body_s* b2_fixture_get_body(b2_fixture_s* fixture) {
    auto b2Fixture = fixture->fixture->GetBody();
    b2_body_s* result = new b2_body_s();
    result->body = b2Fixture;
    return result;
}

b2_shape_type b2_fixture_get_type(b2_fixture_s* fixture) {
    auto fixtureType = fixture->fixture->GetType();
    return (b2_shape_type)fixtureType;
}

b2_shape_s* b2_fixture_get_shape(b2_fixture_s* fixture) {
    auto shape = fixture->fixture->GetShape();
    auto shape_s = new b2_shape_s();
    shape_s->shape = shape;
    return shape_s;
}

// MARK: B2_SHAPE

b2_shape_s* b2_create_polygon_shape() {
    b2PolygonShape* polygonShape = new b2PolygonShape();
    b2_shape_s* shape = new b2_shape_s();
    shape->shape = polygonShape;
    return shape;
}

b2_shape_s* b2_create_circle_shape() {
    b2CircleShape* circleShape = new b2CircleShape();
    b2_shape_s* shape = new b2_shape_s();
    shape->shape = circleShape;
    return shape;
}

void b2_circle_shape_set_position(b2_shape_s* shape, b2_vec2 position) {
    ((b2CircleShape *)shape->shape)->m_p = { position.x, position.y };
}

void b2_shape_set_radius(b2_shape_s* shape, float radius) {
    shape->shape->m_radius = radius;
}

float b2_shape_get_radius(b2_shape_s* shape) {
    return shape->shape->m_radius;
}

void b2_polygon_shape_set(b2_shape_s* polygonShape, const b2_vec2* points, signed int count) {
    b2PolygonShape* shape = (b2PolygonShape *)polygonShape->shape;
    shape->Set((b2Vec2 *)points, count);
}

void b2_polygon_shape_set_as_box(b2_shape_s* polygonShape, float halfWidth, float halfHeight) {
    b2PolygonShape* shape = (b2PolygonShape *)polygonShape->shape;
    shape->SetAsBox(halfWidth, halfHeight);
}

void b2_polygon_shape_set_as_box_with_center(b2_shape_s* polygonShape, float halfWidth, float halfHeight, b2_vec2 center, float angle) {
    b2PolygonShape* shape = (b2PolygonShape *)polygonShape->shape;
    shape->SetAsBox(halfWidth, halfHeight, { center.x, center.y }, angle);
}

b2_shape_type b2_shape_get_type(b2_shape_s* shape) {
    return (b2_shape_type)shape->shape->GetType();
}

void b2_polygon_shape_get_vertices(b2_shape_s* polyginShape, b2_vec2** vertices, uint32_t* count) {
    b2PolygonShape* shape = (b2PolygonShape*)polyginShape->shape;
    auto m_vertices = new b2_vec2[shape->m_count];
    memcpy(m_vertices, &shape->m_vertices, sizeof(b2_vec2) * shape->m_count);
    *vertices = m_vertices;
    *count = shape->m_count;
}

// MARK: B2_CONTACT_LISTENER

class ContactListener2D: public b2ContactListener {
public:
    ContactListener2D(const void *userData): m_UserData(userData) {}
    virtual ~ContactListener2D() {}
    
    virtual void BeginContact(b2Contact* contact) override {
        if (m_BeginContact) {
            auto c_contact = new b2_contact_s();
            c_contact->contact = contact;
            m_BeginContact(m_UserData, c_contact);
            
            delete c_contact;
        }
    }
    
    virtual void EndContact(b2Contact* contact) override {
        if (m_EndContact) {
            auto c_contact = new b2_contact_s();
            c_contact->contact = contact;
            m_EndContact(m_UserData, c_contact);
            
            delete c_contact;
        }
    }
    
    /// This is called after a contact is updated. This allows you to inspect a
    /// contact before it goes to the solver. If you are careful, you can modify the
    /// contact manifold (e.g. disable contact).
    /// A copy of the old manifold is provided so that you can detect changes.
    /// Note: this is called only for awake bodies.
    /// Note: this is called even when the number of contact points is zero.
    /// Note: this is not called for sensors.
    /// Note: if you set the number of contact points to zero, you will not
    /// get an EndContact callback. However, you may get a BeginContact callback
    /// the next step.
    virtual void PreSolve(b2Contact* contact, const b2Manifold* oldManifold) override {
        
    };
    
    /// This lets you inspect a contact after the solver is finished. This is useful
    /// for inspecting impulses.
    /// Note: the contact manifold does not include time of impact impulses, which can be
    /// arbitrarily large if the sub-step is small. Hence the impulse is provided explicitly
    /// in a separate data structure.
    /// Note: this is only called for contacts that are touching, solid, and awake.
    virtual void PostSolve(b2Contact* contact, const b2ContactImpulse* impulse) override {
        
    };
    
    contact_listener_begin_contact_func m_BeginContact;
    contact_listener_end_contact_func m_EndContact;
    contact_listener_presolve_func m_PreSolve;
    contact_listener_postsolve_func m_PostSolve;
    
private:
    const void* m_UserData;
};

contact_listener_s* b2_create_contactListener(const void *userData, contact_listener_callbacks callbacks) {
    ContactListener2D *b2_listener = new ContactListener2D(userData);
    b2_listener->m_BeginContact = callbacks.begin_contact;
    b2_listener->m_EndContact = callbacks.end_contact;
    b2_listener->m_PreSolve = callbacks.pre_solve;
    b2_listener->m_PostSolve = callbacks.post_solve;
    contact_listener_s *listener = new contact_listener_s();
    listener->listener = b2_listener;
    return listener;
}

b2_fixture_s* b2_contact_get_fixture_a(b2_contact_s *contact) {
    auto fixture = contact->contact->GetFixtureA();
    b2_fixture_s *result = new b2_fixture_s();
    result->fixture = fixture;
    return result;
}

b2_fixture_s* b2_contact_get_fixture_b(b2_contact_s *contact) {
    auto fixture = contact->contact->GetFixtureB();
    b2_fixture_s *result = new b2_fixture_s();
    result->fixture = fixture;
    return result;
}

b2_manifold_s* b2_contact_get_manifold(b2_contact_s *contact) {
    auto manifold = contact->contact->GetManifold();
    b2_manifold_s* result = new b2_manifold_s();
    result->manifold = manifold;
    return result;
}
