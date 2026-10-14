import AdaUtils
import Testing

@Suite("Resource identifiers")
struct RIDTests {
    @Test("Rapid concurrent generation produces unique identifiers")
    func concurrentGenerationIsUnique() async {
        let identifiers = await withTaskGroup(of: [RID].self, returning: [RID].self) { group in
            for _ in 0..<8 {
                group.addTask {
                    (0..<2_000).map { _ in RID() }
                }
            }

            var identifiers: [RID] = []
            for await batch in group {
                identifiers.append(contentsOf: batch)
            }
            return identifiers
        }

        #expect(Set(identifiers).count == identifiers.count)
    }
}
