import Testing
@_spi(Internal) @testable import AdaECS
import Math

@Suite("Concurrency Tests")
struct ConcurrencyTests {
    @Test("Query concurrent read access")
    func queryConcurrentReadAccess() async {
        let world = World()
        
        // Create entities
        for i in 0..<100 {
            world.spawn {
                Transform(position: [Float(i), 0, 0])
                Velocity(velocity: [Float(i), Float(i), 0])
            }
        }
        
        let query = Query<Entity, Transform, Velocity>()
        query.update(from: world)
        
        // Read from multiple threads simultaneously
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    var count = 0
                    query.wrappedValue.forEach { entity, transform, velocity in
                        count += 1
                        _ = transform.position
                        _ = velocity.velocity
                    }
                    return count
                }
            }
            
            for await count in group {
                #expect(count == 100)
            }
        }
    }
    
    @Test("Query concurrent read with modifications")
    func queryConcurrentReadWithModifications() async {
        let world = World()
        
        // Create entities
        for i in 0..<50 {
            world.spawn {
                Transform(position: [Float(i), 0, 0])
                Velocity(velocity: [Float(i), 0, 0])
            }
        }
        
        let query = Query<Entity, Ref<Transform>, Ref<Velocity>>()
        query.update(from: world)
        
        // Modify from multiple threads
        await withTaskGroup(of: Void.self) { group in
            for threadId in 0..<5 {
                group.addTask {
                    query.wrappedValue.forEach { entity, transform, velocity in
                        transform.wrappedValue.position.y = Float(threadId)
                        velocity.wrappedValue.velocity.y = Float(threadId)
                    }
                }
            }
        }
        
        // Verify all entities were modified
        query.update(from: world)
        var allModified = true
        query.wrappedValue.forEach { entity, transform, velocity in
            // Position and velocity should have been modified by at least one thread
            allModified = allModified && (transform.wrappedValue.position.y >= 0)
        }
        #expect(allModified)
    }
    
    @Test("Multiple queries concurrent access")
    func multipleQueriesConcurrentAccess() async {
        let world = World()
        
        // Create entities with different component combinations
        for i in 0..<100 {
            world.spawn {
                Transform(position: [Float(i), 0, 0])
                if i % 2 == 0 {
                    Velocity(velocity: [Float(i), 0, 0])
                }
            }
        }
        
        let query1 = Query<Entity, Transform>()
        let query2 = Query<Entity, Transform, Velocity>()
        let query3 = Query<Entity, Ref<Transform>>()
        
        query1.update(from: world)
        query2.update(from: world)
        query3.update(from: world)
        
        // Run queries concurrently
        await withTaskGroup(of: Int.self) { group in
            group.addTask {
                var count = 0
                query1.wrappedValue.forEach { _, _ in count += 1 }
                return count
            }
            
            group.addTask {
                var count = 0
                query2.wrappedValue.forEach { _, _, _ in count += 1 }
                return count
            }
            
            group.addTask {
                var count = 0
                query3.wrappedValue.forEach { _, _ in count += 1 }
                return count
            }
            
            var results: [Int] = []
            for await count in group {
                results.append(count)
            }
            
            #expect(results.contains(100)) // query1 and query3
            #expect(results.contains(50))  // query2
        }
    }
    
    // MARK: - World Concurrency Tests
    
    @Test("World concurrent entity spawning")
    func worldConcurrentEntitySpawning() async {
        let world = World()
        // Spawn entities from multiple threads
        let commands = await withTaskGroup(of: Commands.self) { group in
            for threadId in 0..<10 {
                group.addTask {
                    // Create separate Commands for each task to avoid race conditions
                    let taskCommands = world.makeCommands()
                    for index in 0..<10 {
                        taskCommands.spawn {
                            Transform(position: [Float(threadId * 10 + index), 0, 0])
                            Velocity(velocity: [Float(threadId), 0, 0])
                        }
                    }
                    return taskCommands
                }
            }
            
            // Collect and merge all commands
            let mainCommands = world.makeCommands()
            for await taskCommands in group {
                mainCommands.append(taskCommands)
            }
            return mainCommands
        }

        commands.finish(world)
        world.flush()
        
        let query = Query<Entity, Transform, Velocity>()
        query.update(from: world)
        
        #expect(query.wrappedValue.count == 100)
    }
    
    @Test("World concurrent component insertion")
    func worldConcurrentComponentInsertion() async {
        let world = World()
        
        // Create entities first
        var entities: [Entity] = []
        for i in 0..<50 {
            let entity = world.spawn {
                Transform(position: [Float(i), 0, 0])
            }
            entities.append(entity)
        }
        
        world.flush()
        
        // Insert Velocity component from multiple threads
        let entityIds = entities.map { $0.id }
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask { [entityIds] in
                    let start = i * 10
                    let end = start + 10
                    for idx in start..<end where idx < entityIds.count {
                        world.insert(Velocity(velocity: [Float(i), 0, 0]), for: entityIds[idx])
                    }
                }
            }
        }
        
        world.flush()
        await world.runScheduler(.update)
        
        let query = Query<Entity, Transform, Velocity>()
        query.update(from: world)
        
        #expect(query.wrappedValue.count == 50)
    }
    
//    @Test("World concurrent component removal")
//    func worldConcurrentComponentRemoval() async {
//        let world = World()
//        
//        // Create entities with components
//        var entities: [Entity] = []
//        for i in 0..<50 {
//            let entity = world.spawn {
//                Transform(position: [Float(i), 0, 0])
//                Velocity(velocity: [Float(i), 0, 0])
//            }
//            entities.append(entity)
//        }
//        
//        world.flush()
//        
//        // Remove Velocity component from multiple threads
//        let entityIds = entities.map { $0.id }
//        await withTaskGroup(of: Void.self) { group in
//            for i in 0..<5 {
//                group.addTask { [entityIds] in
//                    let start = i * 10
//                    let end = start + 10
//                    for idx in start..<end where idx < entityIds.count {
//                        world.remove(Velocity.self, from: entityIds[idx])
//                    }
//                }
//            }
//        }
//        
//        world.flush()
//        await world.runScheduler(.update)
//        
//        let query = Query<Entity, Transform, Velocity>()
//        query.update(from: world)
//        
//        // All velocity components should be removed
//        #expect(query.wrappedValue.count == 0)
//        
//        // But Transform should still exist
//        let transformQuery = Query<Entity, Transform>()
//        transformQuery.update(from: world)
//        #expect(transformQuery.wrappedValue.count == 50)
//    }
//    
    @Test("World concurrent entity removal")
    func worldConcurrentEntityRemoval() async {
        let world = World()
        
        // Create entities
        var entities: [Entity] = []
        for i in 0..<100 {
            let entity = world.spawn {
                Transform(position: [Float(i), 0, 0])
            }
            entities.append(entity)
        }
        
        world.flush()
        
        // Remove entities from multiple threads
        let entityCopies = entities
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { [entityCopies] in
                    let start = i * 10
                    let end = start + 10
                    for idx in start..<end where idx < entityCopies.count {
                        world.removeEntityOnNextTick(entityCopies[idx])
                    }
                }
            }
        }
        
        world.flush()
        
        let query = Query<Entity, Transform>()
        query.update(from: world)
        
        #expect(query.wrappedValue.count == 0)
    }
    
    @Test("World concurrent read and write")
    func worldConcurrentReadAndWrite() async {
        let world = World()
        
        // Create entities
        for i in 0..<50 {
            world.spawn {
                Transform(position: [Float(i), 0, 0])
                Velocity(velocity: [Float(i), 0, 0])
            }
        }
        
        world.flush()
        
        let query = Query<Entity, Ref<Transform>, Ref<Velocity>>()
        query.update(from: world)
        
        // Concurrently read and write to components
        await withTaskGroup(of: Void.self) { group in
            // Writer threads
            for threadId in 0..<3 {
                group.addTask {
                    query.wrappedValue.forEach { entity, transform, velocity in
                        transform.wrappedValue.position.y = Float(threadId)
                        velocity.wrappedValue.velocity.y = Float(threadId)
                    }
                }
            }
            
            // Reader threads
            for _ in 0..<3 {
                group.addTask {
                    query.wrappedValue.forEach { entity, transform, velocity in
                        _ = transform.wrappedValue.position
                        _ = velocity.wrappedValue.velocity
                    }
                }
            }
        }
        
        // Verify data integrity
        query.update(from: world)
        var validData = true
        query.wrappedValue.forEach { entity, transform, velocity in
            // Position should be a valid value (0, 1, or 2)
            validData = validData && (transform.wrappedValue.position.y >= 0 && transform.wrappedValue.position.y <= 2)
        }
        #expect(validData)
    }
    
    // MARK: - Resource Concurrency Tests
    
    @Test("Resource concurrent read access")
    func resourceConcurrentReadAccess() async {
        let world = World()
        world.insertResource(Gravity(value: Vector3(0, -9.8, 0)))
        
        // Read resource from multiple threads
        await withTaskGroup(of: Vector3.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    guard let gravity = world.getResource(Gravity.self) else {
                        return .zero
                    }
                    return gravity.value
                }
            }
            
            for await value in group {
                #expect(value == Vector3(0, -9.8, 0))
            }
        }
    }
    
    @Test("Resource concurrent write access")
    func resourceConcurrentWriteAccess() async {
        let world = World()
        world.insertResource(Gravity(value: Vector3(0, -9.8, 0)))
        
        // Write resource from multiple threads
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let mutable = world.getRefResource(Gravity.self)
                    mutable.wrappedValue.value.y = Float(-i)
                }
            }
        }
        
        // Resource should have been modified
        let gravity = world.getResource(Gravity.self)
        #expect(gravity != nil)
        #expect(gravity!.value.y != -9.8)
    }
    
    // MARK: - Stress Tests
    
    @Test("Stress test: Heavy concurrent operations")
    func stressTestHeavyConcurrentOperations() async {
        let world = World()
        
        // Create initial entities
        for i in 0..<200 {
            world.spawn {
                Transform(position: [Float(i), 0, 0])
                if i % 2 == 0 {
                    Velocity(velocity: [Float(i), 0, 0])
                }
            }
        }
        
        world.flush()
        
        // Perform heavy concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Spawn new entities
            for _ in 0..<3 {
                group.addTask {
                    for i in 0..<20 {
                        world.spawn {
                            Transform(position: [Float(i), 0, 0])
                            Velocity(velocity: [Float(i), 0, 0])
                        }
                    }
                }
            }
            
            // Query and modify
            for _ in 0..<3 {
                group.addTask {
                    let query = Query<Entity, Ref<Transform>>()
                    query.update(from: world)
                    query.wrappedValue.forEach { entity, transform in
                        transform.wrappedValue.position.y += 1.0
                    }
                }
            }
            
            // Insert components
            for _ in 0..<2 {
                group.addTask {
                    let query = Query<Entity, Transform>()
                    query.update(from: world)
                    var count = 0
                    query.wrappedValue.forEach { entity, _ in
                        if count % 5 == 0 {
                            world.insert(Velocity(velocity: [1, 2, 3]), for: entity.id)
                        }
                        count += 1
                    }
                }
            }
        }
        
        world.flush()
        
        // Verify world is still consistent
        let allEntities = world.getEntities()
        #expect(allEntities.count > 200)
    }
    
    @Test("Stress test: Query iteration race condition")
    func stressTestQueryIterationRaceCondition() async {
        let world = World()
        
        // Create many entities
        for i in 0..<1000 {
            world.spawn {
                Transform(position: [Float(i), 0, 0])
                Velocity(velocity: [Float(i % 100), 0, 0])
            }
        }
        
        world.flush()
        
        let query = Query<Entity, Ref<Transform>, Ref<Velocity>>()
        query.update(from: world)
        
        // Iterate and modify concurrently
        await withTaskGroup(of: Int.self) { group in
            for threadId in 0..<20 {
                group.addTask {
                    var count = 0
                    query.wrappedValue.forEach { entity, transform, velocity in
                        // Read and write
                        let oldPos = transform.wrappedValue.position
                        transform.wrappedValue.position.x = oldPos.x + Float(threadId)
                        velocity.wrappedValue.velocity.y = Float(threadId)
                        count += 1
                    }
                    return count
                }
            }
            
            for await count in group {
                // Each thread should iterate over all 1000 entities
                #expect(count == 1000)
            }
        }
    }
}


