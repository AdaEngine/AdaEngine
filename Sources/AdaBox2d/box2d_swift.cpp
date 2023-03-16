//
//  box2d_swift.c
//  
//
//  Created by v.prusakov on 3/14/23.
//

#include <stdio.h>
#include "box2d_swift.hpp"

// FIXME: fix PreSolve and PostSolve methods.

namespace ada {

b2PolygonShape* b2PolygonShape_create() {
    return new b2PolygonShape();
}

void b2Polygon_delete(b2PolygonShape *shape) {
    delete shape;
}

b2CircleShape* b2CircleShape_create() {
    return new b2CircleShape();
}

void b2CircleShape_delete(b2CircleShape *shape) {
    delete shape;
}

const b2Shape* b2Shape_unsafeCast(void *shape) {
    return (const b2Shape *)shape;
}

float& b2Shape_GetRadius(b2Shape *shape) {
    return shape->m_radius;
}

// b2Shape end

// b2Joint

const b2JointDef* b2JointDef_unsafeCast(void *joint) {
    return (const b2JointDef *)joint;
}

// b2Joint end

// b2World

b2World* b2World_create(const b2Vec2& gravity) {
    return new b2World(gravity);
}

void b2World_delete(b2World *world) {
    delete world;
}

// b2World end

// b2ContactListner

ContactListener2D::ContactListener2D(const void *userData): m_UserData(userData) {}

ContactListener2D::~ContactListener2D() {}

void ContactListener2D::BeginContact(b2Contact* contact) {
    m_BeginContact(m_UserData, contact);
}

void ContactListener2D::EndContact(b2Contact* contact) {
    m_EndContact(m_UserData, contact);
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
void ContactListener2D::PreSolve(b2Contact* contact, const b2Manifold* oldManifold) {
//    if (m_PreSolve != nullptr)
//        m_PreSolve(m_UserData, contact, oldManifold);
}

/// This lets you inspect a contact after the solver is finished. This is useful
/// for inspecting impulses.
/// Note: the contact manifold does not include time of impact impulses, which can be
/// arbitrarily large if the sub-step is small. Hence the impulse is provided explicitly
/// in a separate data structure.
/// Note: this is only called for contacts that are touching, solid, and awake.
void ContactListener2D::PostSolve(b2Contact* contact, const b2ContactImpulse* impulse) {
//    if (m_PostSolve != nullptr)
//        m_PostSolve(m_UserData, contact, impulse);
}

ContactListener2D* ContactListener2D_create(const void *userData) {
    return new ContactListener2D(userData);
}

b2ContactListener* b2ContactListener_unsafeCast(void *ptr) {
    return (b2ContactListener*)ptr;
}

}