import AdaApp
import AdaECS
import AdaNavigation
import AdaTransform
import Foundation
import Math

/// Install a replacement resource to invalidate existing routes after a new bake or scene change.
public struct NavigationMap3D: Resource, Sendable {
    public let mesh: NavigationMesh
    public let revision: UUID
    public var maximumRequestsPerUpdate: Int
    public var queryOptions: NavigationQueryOptions

    public init(mesh: NavigationMesh, maximumRequestsPerUpdate: Int = 4, queryOptions: NavigationQueryOptions = NavigationQueryOptions()) {
        self.mesh = mesh
        self.revision = UUID()
        self.maximumRequestsPerUpdate = maximumRequestsPerUpdate
        self.queryOptions = queryOptions
    }
}

/// A world-space destination. Set destination to nil to cancel movement.
@Component
public struct NavigationTarget3DComponent: Codable, Sendable {
    public var destination: Vector3?

    @AdaScriptInit
    public init(destination: Vector3? = nil) {
        self.destination = destination
    }
}

/// Makes bounded, structured requests; no ECS reference is retained across an await.
@PlainSystem
public struct NavigationPathRequest3DSystem {
    @Query<Entity, Ref<NavigationAgent3DComponent>, NavigationTarget3DComponent, Transform>
    private var agents
    @Res<NavigationMap3D?> private var navigation
    @Res<DeltaTime?> private var time
    @Local private var nextCandidate: Int = 0

    public init(world _: World) {}

    @MainActor
    public func update(context: UpdateContext) async {
        let deltaTime = time?.deltaTime ?? 1.0 / 60
        var candidates: [Request] = []
        agents.forEach { entity, agent, target, transform in
            guard let destination = target.destination, let navigation else {
                agent.follower.cancel()
                agent.lastRequestedTarget = nil
                agent.mapRevision = nil
                agent.lastError = nil
                return
            }
            guard destination.x.isFinite, destination.y.isFinite, destination.z.isFinite else {
                agent.follower.cancel()
                agent.lastRequestedTarget = nil
                agent.lastError = .invalidQuery
                return
            }
            agent.elapsedSinceRequest += deltaTime.isFinite ? max(0, deltaTime) : 0
            guard agent.repathInterval.isFinite, agent.repathInterval > 0,
                agent.targetRepathDistance.isFinite, agent.targetRepathDistance > 0 else {
                agent.follower.cancel()
                agent.lastError = .invalidSettings
                return
            }
            let moved = agent.lastRequestedTarget.map { (destination - $0).length >= agent.targetRepathDistance } ?? true
            let changedMap = agent.mapRevision != navigation.revision
            if moved || changedMap { agent.follower.cancel() }
            let retry = agent.elapsedSinceRequest >= agent.repathInterval
                && (agent.lastError != nil || agent.follower.state == .blocked)
            let offset = destination - transform.position
            let endedAwayFromGoal = agent.follower.state == .arrived
                && (Vector3(offset.x, 0, offset.z).length > agent.follower.arrivalTolerance || abs(offset.y) > agent.follower.heightTolerance)
            let needsRoute = agent.follower.state == .idle && agent.lastError == nil
            if moved || changedMap || retry || endedAwayFromGoal || needsRoute {
                candidates.append(Request(entity: entity.id, start: transform.position, target: destination, serial: 0))
            }
        }
        guard let navigation, !candidates.isEmpty else { return }
        let budget = min(max(navigation.maximumRequestsPerUpdate, 1), 64)
        let startIndex = nextCandidate % candidates.count
        nextCandidate = (startIndex + min(budget, candidates.count)) % candidates.count
        // Materialize all state before suspending, then check it again before applying a reply.
        var requests: [Request] = []
        for offset in 0..<min(budget, candidates.count) {
            var request = candidates[(startIndex + offset) % candidates.count]
            guard let entity = context.world.getEntityByID(request.entity),
                var agent = entity.components[NavigationAgent3DComponent.self] else { continue }
            agent.requestSerial &+= 1
            request.serial = agent.requestSerial
            agent.lastRequestedTarget = request.target
            agent.mapRevision = navigation.revision
            agent.elapsedSinceRequest = 0
            agent.lastError = nil
            agent.follower.cancel()
            entity.components[NavigationAgent3DComponent.self] = agent
            requests.append(request)
        }
        for request in requests {
            let result: Result<NavigationRoute, NavigationError>
            do throws(NavigationError) {
                result = .success(try await navigation.mesh.findPath(from: request.start, to: request.target, options: navigation.queryOptions))
            } catch let error {
                result = .failure(error)
            }
            guard context.world.getResource(NavigationMap3D.self)?.revision == navigation.revision,
                let entity = context.world.getEntityByID(request.entity),
                entity.components[NavigationTarget3DComponent.self]?.destination == request.target,
                entity.components[Transform.self]?.position == request.start,
                var agent = entity.components[NavigationAgent3DComponent.self],
                agent.requestSerial == request.serial else { continue }
            switch result {
            case let .success(path): agent.follower.follow(path)
            case let .failure(error): agent.lastError = error
            }
            entity.components[NavigationAgent3DComponent.self] = agent
        }
    }
}

private struct Request {
    let entity: Entity.ID
    let start: Vector3
    let target: Vector3
    var serial: UInt64
}
