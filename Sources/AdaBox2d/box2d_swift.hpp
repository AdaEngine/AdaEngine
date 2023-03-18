//
//  box2d_swift.h
//  
//
//  Created by v.prusakov on 3/14/23.
//

#ifndef BOX2D_SWIFT_h
#define BOX2D_SWIFT_h

#include <box2d/box2d.h>

typedef struct contact_listener_s contact_listener_t;
typedef struct contact_listener_s contact_listener_t;

// That's is a swift compiler restriction. If we will write code in header file, than we will get duplicate symbols error in swift.

namespace ada {

// b2Shape

b2PolygonShape* b2PolygonShape_create();

void b2Polygon_delete(b2PolygonShape *shape);

b2CircleShape* b2CircleShape_create();

void b2CircleShape_delete(b2CircleShape *shape);

const b2Shape* b2Shape_unsafeCast(void *shape);

float& b2Shape_GetRadius(b2Shape *shape);

// b2Shape end

// b2Joint

const b2JointDef* b2JointDef_unsafeCast(void *joint);

// b2Joint end

// b2World

b2World* b2World_create(const b2Vec2& gravity);

void b2World_delete(b2World *world);

// b2World end
//
//ContactListener2D* ContactListener2D_create(const void *userData);
//
//b2ContactListener* b2ContactListener_unsafeCast(void *ptr);

// b2ContactListner end

}

#endif /* BOX2D_SWIFT_h */
