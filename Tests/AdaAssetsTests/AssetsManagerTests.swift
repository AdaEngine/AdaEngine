#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
@testable @_spi(AdaEngine) import AdaAssets
import Math

@Suite("AssetsManager Tests")
struct AssetsManagerTests: Sendable {

    @AssetActor
    init() async throws {
        // Set up test environment
        let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AssetsManagerTests")
        try? FileManager.default.removeItem(at: testDirectory)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        // Initialize AssetsManager with test directory
        try AssetsManager.initialize(filePath: #filePath)
        try AssetsManager.setAssetDirectory(testDirectory)
        AssetsManager.registerAssetType(TestAsset.self)
    }
    
    @Test("Loading non-existent asset should throw error")
    func testLoadNonExistentAsset() async throws {
        // Test loading a non-existent asset
        await #expect(throws: AssetError.self) {
            _ = try await AssetsManager.load(TestAsset.self, at: "@res://non_existent.txt")
        }
    }
    
    @Test("Loading same asset twice should return cached instance")
    func testLoadAndCacheAsset() async throws {
        // Create a test asset
        let testPath = "@res://test_texture.txt"
        let testData = TestAsset(testData: "1234") // Sample image data
        
        // Save test asset
        try await AssetsManager.save(testData, at: "@res://", name: "test_texture.txt")
        
        // Verify asset is not in cache initially
        let isExists = await AssetsManager.isAssetExistsInCache(TestAsset.self, at: testPath)
        #expect(!isExists, "Asset should not be in cache initially")
        
        // Load asset first time
        let handle1 = try await AssetsManager.load(TestAsset.self, at: testPath)
        
        // Verify asset is in cache after first load
        let isExistsAfterLoad = await AssetsManager.isAssetExistsInCache(TestAsset.self, at: testPath)
        #expect(isExistsAfterLoad, "Asset should be in cache after first load")
        
        // Load asset second time (should use cache)
        let handle2 = try await AssetsManager.load(TestAsset.self, at: testPath)
        
        // Verify both handles point to the same instance
        #expect(handle1.asset === handle2.asset, "Cached asset should return the same instance")
    }
    
    @Test("Synchronous loading should work")
    func testLoadSync() async throws {
        // Create a test asset
        let testPath = "@res://test_texture_sync.txt"
        let testData = TestAsset(testData: "12345") // Sample image data
        
        // Save test asset
        try await AssetsManager.save(testData, at: "@res://", name: "test_texture_sync.txt")
        
        // Verify asset is not in cache initially
        let isExists = await AssetsManager.isAssetExistsInCache(TestAsset.self, at: testPath)
        #expect(!isExists, "Asset should not be in cache initially")
        
        // Load asset synchronously
        let asset = try AssetsManager.loadSync(TestAsset.self, at: testPath)
        
        // Verify asset is in cache after sync load
        let isExistsAfterLoadSync = await AssetsManager.isAssetExistsInCache(TestAsset.self, at: testPath)
        #expect(isExistsAfterLoadSync, "Asset should be in cache after sync load")
        print(asset)
    }
    
    @Test("Saving asset should work")
    func testSaveAsset() async throws {
        // Create a test asset
        let testPath = "@res://test_save.txt"
        let testAsset = TestAsset(testData: "save") // Create with empty image for testing
        
        // Save asset
        try await AssetsManager.save(testAsset, at: "@res://", name: "test_save.txt")
        
        // Verify asset exists
        let fileURL = AssetsManager.getFilePath(at: testPath)
        #expect(FileManager.default.fileExists(atPath: fileURL.path), "Saved asset should exist")
        
        // Verify asset is not in cache initially
        let isExists = await AssetsManager.isAssetExistsInCache(TestAsset.self, at: testPath)
        #expect(!isExists, "Asset should not be in cache initially")
        
        // Load saved asset
        let asset = try await AssetsManager.load(TestAsset.self, at: testPath)
        
        // Verify asset is in cache after load
        let isExistsAfterLoad = await AssetsManager.isAssetExistsInCache(TestAsset.self, at: testPath)
        #expect(isExistsAfterLoad, "Asset should be in cache after load")
        print(asset)
    }
    
    @Test("Hot reloading should work")
    func testHotReloading() async throws {
        // Create a test asset
        let testPath = "@res://test_hot_reload.txt"
        let testData = TestAsset(testData: "1234")// Sample image data
        
        // Save test asset
        try await AssetsManager.save(testData, at: "@res://", name: "test_hot_reload.txt")
        
        // Verify asset is not in cache initially
        let isExists = await AssetsManager.isAssetExistsInCache(TestAsset.self, at: testPath)
        #expect(!isExists, "Asset should not be in cache initially")
        
        // Load asset with hot reloading enabled
        let asset = try await AssetsManager.load(TestAsset.self, at: testPath, handleChanges: true)
        
        // Verify asset is in cache after load
        let isExistsAfterLoad = await AssetsManager.isAssetExistsInCache(TestAsset.self, at: testPath)
        #expect(isExistsAfterLoad, "Asset should be in cache after load")
        
        // Modify the asset file
        let newData = TestAsset(testData: "12345")
        try await AssetsManager.save(newData, at: "@res://", name: "test_hot_reload.txt")
        
        // Wait for hot reload
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Verify asset is still in cache after hot reload
        let isExistsAfterHotReloading = await AssetsManager.isAssetExistsInCache(TestAsset.self, at: testPath)
        #expect(isExistsAfterHotReloading, "Asset should still be in cache after hot reload")
        
        // Load asset again to verify hot reload
        _ = try await AssetsManager.load(TestAsset.self, at: testPath)
        
        print(asset)
    }
} 

private extension AssetsManager {
    static func getFilePath(at path: String) -> URL {
        self.getFilePath(
            from: AssetMetaInfo(
                assetPath: path,
                assetName: "",
                bundlePath: nil
            )
        ).url
    }
}

final class TestAsset: Asset, @unchecked Sendable {
    
    let testData: String
    
    init(testData: String) {
        self.testData = testData
    }
    
    init(from assetDecoder: any AssetDecoder) throws {
        self.testData = try assetDecoder.decode(String.self)
    }
    
    func encodeContents(with assetEncoder: any AssetEncoder) throws {
        try assetEncoder.encode(self.testData)
    }
    
    static func extensions() -> [String] {
        ["txt"]
    }
    
    var assetMetaInfo: AssetMetaInfo?
}
