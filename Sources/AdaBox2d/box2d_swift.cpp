//
//  box2d_swift.c
//  
//
//  Created by v.prusakov on 3/14/23.
//

#include <stdio.h>
#include "box2d_swift.hpp"
#include <box2d/box2d.h>
#include <ContactListner2D.hpp>

typedef struct contact_listener_s {
//    glslang::TShader* shader;
//    std::string preprocessedGLSL;
} contact_listener_t;

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


//ContactListener2D* ContactListener2D_create(const void *userData) {
//    return new ContactListener2D(userData);
//}
//
//b2ContactListener* b2ContactListener_unsafeCast(void *ptr) {
//    return (b2ContactListener*)ptr;
//}

}
