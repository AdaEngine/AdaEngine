//
//  box2d_swift.h
//  
//
//  Created by v.prusakov on 3/14/23.
//

#ifndef BOX2D_SWIFT_h
#define BOX2D_SWIFT_h

#include <box2d/box2d.h>

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

// b2ContactListner

class ContactListener2D: public b2ContactListener {
public:
    ContactListener2D(const void *userData);
    ~ContactListener2D();
    
    virtual void BeginContact(b2Contact* contact) override;
    
    virtual void EndContact(b2Contact* contact) override;
    
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
    virtual void PreSolve(b2Contact* contact, const b2Manifold* oldManifold) override;
    
    /// This lets you inspect a contact after the solver is finished. This is useful
    /// for inspecting impulses.
    /// Note: the contact manifold does not include time of impact impulses, which can be
    /// arbitrarily large if the sub-step is small. Hence the impulse is provided explicitly
    /// in a separate data structure.
    /// Note: this is only called for contacts that are touching, solid, and awake.
    virtual void PostSolve(b2Contact* contact, const b2ContactImpulse* impulse) override;
    
    void(*m_BeginContact)(const void *userData, b2Contact* contact);
    void(*m_EndContact)(const void *userData, b2Contact* contact);
    void(*m_PreSolve)(const void *userData, b2Contact* contact, const b2Manifold* oldManifold);
    void(*m_PostSolve)(const void *userData, b2Contact* contact, const b2ContactImpulse* impulse);
    
private:
    const void* m_UserData;
};

ContactListener2D* ContactListener2D_create(const void *userData);

b2ContactListener* b2ContactListener_unsafeCast(void *ptr);

// b2ContactListner end

}

#endif /* BOX2D_SWIFT_h */
