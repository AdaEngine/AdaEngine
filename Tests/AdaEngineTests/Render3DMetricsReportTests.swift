@testable import AdaCorePipelines
import Testing

@Suite("3D GPU pass timing report")
struct Render3DMetricsReportTests {
    @Test func emptyMetricsSayNothingWasMeasured() {
        let metrics = Render3DPerformanceMetrics(warmupSamples: 0)
        #expect(metrics.report() == "No GPU pass timings recorded yet.")
        #expect(metrics.totalAverageMilliseconds == 0)
    }

    @Test func reportListsPassesSlowestFirstWithATotal() {
        let metrics = Render3DPerformanceMetrics(warmupSamples: 0)
        for seconds in [0.001, 0.003] { metrics.record(pass: "geometry", seconds: seconds) }
        metrics.record(pass: "bloom", seconds: 0.0005)
        metrics.record(pass: "temporal", seconds: 0.0012)
        let lines = metrics.report().split(separator: "\n").map(String.init)
        #expect(lines.count == 5)
        #expect(lines[0].hasPrefix("pass") && lines[0].contains("avg ms") && lines[0].hasSuffix("frames"))
        #expect(lines[1].hasPrefix("geometry") && lines[1].contains("2.000") && lines[1].contains("1.000") && lines[1].contains("3.000"))
        #expect(lines[2].hasPrefix("temporal"))
        #expect(lines[3].hasPrefix("bloom") && lines[3].contains("0.500"))
        #expect(lines[4].hasPrefix("total") && lines[4].hasSuffix("3.700"))
        #expect(abs(metrics.totalAverageMilliseconds - 3.7) < 1e-9)
    }

    @Test func columnsAlignAcrossRows() {
        let metrics = Render3DPerformanceMetrics(warmupSamples: 0)
        metrics.record(pass: "ssao", seconds: 0.0042)
        metrics.record(pass: "directionalShadowCascades", seconds: 0.0123)
        let lines = metrics.report().split(separator: "\n").map(String.init)
        #expect(Set(lines.dropLast().map(\.count)).count == 1, "Rows must share one width: \(lines)")
    }

    @Test func warmupSamplesAreExcludedAndFailedTimingsIgnored() {
        let metrics = Render3DPerformanceMetrics(warmupSamples: 2)
        for _ in 0..<2 { metrics.record(pass: "geometry", seconds: 0.1) }
        metrics.record(pass: "geometry", seconds: 0.002)
        metrics.record(pass: "geometry", seconds: nil)
        metrics.record(pass: "geometry", seconds: .nan)
        metrics.record(pass: "geometry", seconds: 0)
        let sample = metrics.samples.first
        #expect(sample?.count == 1)
        #expect(sample?.averageMilliseconds == 2)
    }
}
