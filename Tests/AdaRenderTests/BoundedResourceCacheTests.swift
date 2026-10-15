import Testing

@testable import AdaRender

@Suite
struct BoundedResourceCacheTests {
    private final class Owner {}

    @Test
    func bindingsReuseValuesRetainOwnersAndRespectTheCapacity() {
        var cache = BoundedResourceCache<Int, Int>(capacity: 2)
        var owner: Owner? = Owner()
        weak var retained = owner
        #expect(cache.value(for: 1, owners: owner.map { [$0] } ?? [], create: { 42 }) == 42)
        owner = nil
        #expect(retained != nil)
        #expect(
            cache.value(
                for: 1,
                owners: [],
                create: {
                    Issue.record("Cache hit rebuilt the binding")
                    return nil
                }
            ) == 42
        )
        #expect(cache.value(for: 2, owners: [], create: { 43 }) == 43)
        #expect(cache.value(for: 3, owners: [], create: { 44 }) == 44)
        #expect(retained == nil)
        #expect(cache.value(for: 2, owners: [], create: {
            Issue.record("Overflow discarded an unrelated binding")
            return nil
        }) == 43)
        #expect(cache.value(for: 1, owners: [], create: { 45 }) == 45)
    }

    @Test
    func failedCreationCanBeRetried() {
        var cache = BoundedResourceCache<Int, Int>(capacity: 1)
        #expect(cache.value(for: 1, owners: [], create: { nil }) == nil)
        #expect(cache.value(for: 1, owners: [], create: { 7 }) == 7)
    }

    @Test
    func failedCreationDoesNotEvictExistingBindings() {
        var cache = BoundedResourceCache<Int, Int>(capacity: 1)
        _ = cache.value(for: 1, owners: [], create: { 7 })
        #expect(cache.value(for: 2, owners: [], create: { nil }) == nil)
        #expect(cache.value(for: 1, owners: [], create: { nil }) == 7)
    }

    @Test
    func ringWraparoundRetainsExactlyTheNewestBindings() {
        var cache = BoundedResourceCache<Int, Int>(capacity: 3)
        for key in 0..<20 { #expect(cache.value(for: key, owners: [], create: { key }) == key) }
        for key in 17..<20 { #expect(cache.value(for: key, owners: [], create: { nil }) == key) }
        #expect(cache.value(for: 16, owners: [], create: { nil }) == nil)
    }

    @Test
    func copiedCacheEvictsIndependently() {
        var first = BoundedResourceCache<Int, Int>(capacity: 1)
        _ = first.value(for: 1, owners: [], create: { 7 })
        var second = first
        _ = second.value(for: 2, owners: [], create: { 8 })
        #expect(first.value(for: 1, owners: [], create: { nil }) == 7)
        #expect(first.value(for: 2, owners: [], create: { nil }) == nil)
        #expect(second.value(for: 1, owners: [], create: { nil }) == nil)
    }

    @Test
    func gardenSizedCascadeWorkingSetStaysWarmAfterInitialFrames() {
        // 539 material identities × three frame buffers × three shadow cascades.
        let workingSet = 539 * 3 * 3
        var cache = BoundedResourceCache<Int, Int>(capacity: 8_192)
        var creations = 0
        for _ in 0..<3 {
            for key in 0..<workingSet {
                _ = cache.value(for: key, owners: [], create: { creations += 1; return key })
            }
        }
        #expect(creations == workingSet)
    }
}
