@testable import AdaUtils
import Testing

@Suite
struct UniqueHashableTests {

    @Test
    func `consistency of FNVHasher with String`() {
        let str1 = "Hello, AdaEngine!"
        let str2 = "Hello, AdaEngine!"
        let str3 = "Different String"
        
        var hasher1 = FNVHasher()
        str1.hash(into: &hasher1)
        let hash1 = hasher1.finalize()
        
        var hasher2 = FNVHasher()
        str2.hash(into: &hasher2)
        let hash2 = hasher2.finalize()
        
        var hasher3 = FNVHasher()
        str3.hash(into: &hasher3)
        let hash3 = hasher3.finalize()
        
        #expect(hash1 == hash2)
        #expect(hash1 != hash3)
        
        // Test convenience property
        #expect(str1.uniqueHashValue == str2.uniqueHashValue)
        #expect(str1.uniqueHashValue != str3.uniqueHashValue)
    }

    @Test("Test integer hashing")
    func testIntegerHashing() {
        let int1: Int = 42
        let int2: Int = 42
        let int3: Int = 100
        
        #expect(int1.uniqueHashValue == int2.uniqueHashValue)
        #expect(int1.uniqueHashValue != int3.uniqueHashValue)
    }
    
    @Test
    func `float and double hashing`() {
        let double1: Double = 3.14159
        let double2: Double = 3.14159
        let double3: Double = 2.71828
        
        #expect(double1.uniqueHashValue == double2.uniqueHashValue)
        #expect(double1.uniqueHashValue != double3.uniqueHashValue)
    }
    
    @Test
    func `primitive types consistency`() {
        let u8: UInt8 = 255
        let u32: UInt32 = 123456
        let u64: UInt64 = 12345678901234
        
        #expect(u8.uniqueHashValue == u8.uniqueHashValue)
        #expect(u32.uniqueHashValue == u32.uniqueHashValue)
        #expect(u64.uniqueHashValue == u64.uniqueHashValue)
    }

    @Test
    func `hasher combine mixed types`() {
        var hasher1 = FNVHasher()
        hasher1.combine(42)
        hasher1.combine("Ada")
        let result1 = hasher1.finalize()
        
        var hasher2 = FNVHasher()
        hasher2.combine(42)
        hasher2.combine("Ada")
        let result2 = hasher2.finalize()
        
        var hasher3 = FNVHasher()
        hasher3.combine(42)
        hasher3.combine("Beta")
        let result3 = hasher3.finalize()
        
        #expect(result1 == result2)
        #expect(result1 != result3)
    }

    @Test
    func `same hash for string between launches`() {
        let hash1 = "Hello, AdaEngine!".uniqueHashValue
        #expect(hash1 == 6458726915318513084)
    }

    @Test
    func `same hash for double between launches`() {
        let double1: Double = 3.14159
        #expect(double1.uniqueHashValue == -1627972450653492632)
    }

    @Test
    func `same hash for int between launches`() {
        let int1: Int = 42
        #expect(int1.uniqueHashValue == -55488592825689361)
    }
}
