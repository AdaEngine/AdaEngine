import Testing
@_spi(Internal) @testable import AdaECS
import Math

@Component
struct Transform {
    var position: Vector3 = .zero
}

@Component
struct Velocity {
    var velocity: Vector3 = .zero
}

struct QueryTests {
    @Test("Query fetch components")
    func queryFetchComponents() {
        let world = World()

        for _ in 0..<10 {
            let entity = Entity()
            entity.components += Transform()
            entity.components += Velocity()

            world.addEntity(entity)
        }

        world.build()

        let query = Query<Entity, Transform, Velocity>()
        query.update(from: world)


        #expect(query.wrappedValue.count == 10)
        query.wrappedValue.forEach { entity, transform, velocity in
            #expect(transform.position == .zero)
            #expect(velocity.velocity == .zero)
        }
    }

    @Test("Query with ref components")
    func queryWithRefComponents() {
        let world = World()
        
        for i in 0..<5 {
            let entity = Entity()
            entity.components += Transform(position: [Float(i), 0, 0])
            world.addEntity(entity)
        }
        
        world.build()
        
        let query = Query<Entity, Ref<Transform>>()
        query.update(from: world)
        
        #expect(query.wrappedValue.count == 5)
        
        // Test we can modify components through refs
        query.wrappedValue.forEach { entity, transform in
            transform.wrappedValue.position.y = 10
        }
        
        query.wrappedValue.forEach { entity, transform in
            #expect(transform.wrappedValue.position.y == 10)
        }
    }
    
    @Test("Query with where clause")
    func queryWithWhereClause() {
        let world = World()
        
        // Add entities with different component combinations
        for i in 0..<10 {
            let entity = Entity()
            entity.components += Transform()
            
            if i % 2 == 0 {
                entity.components += Velocity() 
            }
            
            world.addEntity(entity)
        }
        
        world.build()
        
        // Query only entities with both Transform and Velocity
        let query = Query<Entity, Transform, Velocity>()
        query.update(from: world)
        
        #expect(query.wrappedValue.count == 5)
    }
    
    @Test("Query updates when entities change")
    func queryUpdatesWithEntityChanges() async {
        let world = World()
        
        let query = Query<Entity, Transform>()
        query.update(from: world)
        #expect(query.wrappedValue.count == 0)
        
        // Add entity
        let entity = Entity()
        entity.components += Transform()
        world.addEntity(entity)
        world.build()
        
        query.update(from: world)
        #expect(query.wrappedValue.count == 1)
        
        // Remove component
        entity.components.remove(Transform.self)
        await world.update(1.0 / 60.0)
        
        query.update(from: world)
        #expect(query.wrappedValue.count == 0)
    }
}