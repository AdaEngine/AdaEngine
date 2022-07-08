//
//  b2_swift.h
//  box2d
//
//  Created by v.prusakov on 7/8/22.
//

#ifndef b2_swift_h
#define b2_swift_h

typedef void (*b2_contact_function)(b2Contact* contact, void* userObject);
typedef void (*b2_contact_deinit_function)(void* userObject);

class b2ContactListener;
class b2Contact;

class b2_swift_ContactListener: public b2ContactListener {
public:
    
    b2_swift_ContactListener(void* userObject): m_UserObject(userObject) { }
    ~b2_swift_ContactListener() {
        m_Deconstructor(m_UserObject);
    }
    
    void BeginContact(b2Contact* contact) {
        m_BeginContact(contact, m_UserObject);
    }
    
    void EndContact(b2Contact* contact) {
        m_EndContact(contact, m_UserObject);
    }
    
    b2_contact_function m_BeginContact;
    b2_contact_function m_EndContact;
    b2_contact_deinit_function m_Deconstructor;
private:
    void* m_UserObject;
};

#endif /* b2_swift_h */
