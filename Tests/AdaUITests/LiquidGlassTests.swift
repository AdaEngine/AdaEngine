import Testing
@testable import AdaUI
import AdaCorePipelines
import AdaUtils
import Math

struct LiquidGlassTests {

    @Test
    func regularClearAndIdentityExposeLiquidGlassDefaults() {
        let regular = Glass.regular
        #expect(regular.cornerRoundnessExponent == 4.8)
        #expect(regular.blurRadius == 8.0)
        #expect(regular.glassThickness == 28.0)
        #expect(regular.refractiveIndex == 1.20)
        #expect(regular.dispersionStrength == 0.0)
        #expect(regular.fresnelIntensity == 0.84)
        #expect(regular.glareIntensity == 0.88)
        #expect(regular.tintColor == Color(red: 0.97, green: 0.985, blue: 1.0, alpha: 0.07))

        let interaction = Glass.interaction
        #expect(interaction.blurRadius == 9.5)
        #expect(interaction.glassTintStrength == 1.0)
        #expect(interaction.fresnelIntensity == 0.96)
        #expect(interaction.glareIntensity == 1.0)
        #expect(interaction.tintColor == Color(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.16))

        let clear = Glass.clear
        #expect(clear.blurRadius == 2.5)
        #expect(clear.glassThickness == 22.0)
        #expect(clear.dispersionStrength == 0.0)
        #expect(clear.fresnelIntensity == 0.38)
        #expect(clear.glareIntensity == 0.28)
        #expect(clear.tintColor == Color(red: 0.98, green: 0.99, blue: 1.0, alpha: 0.03))

        let identity = Glass.identity
        #expect(identity.blurRadius == 0.0)
        #expect(identity.glassTintStrength == 0.0)
        #expect(identity.opacity == 0.0)
        #expect(identity.glassThickness == 0.0)
        #expect(identity.dispersionStrength == 0.0)
        #expect(identity.fresnelIntensity == 0.0)
        #expect(identity.glareIntensity == 0.0)
        #expect(identity.tintColor == .clear)
    }

    @Test
    func fluentSettersOnlyChangeTargetValues() {
        let base = Glass.regular
        let updated = base
            .blurRadius(14.0)
            .glassTintStrength(0.33)
            .edgeShadowStrength(0.05)
            .cornerRoundnessExponent(5.5)
            .glassThickness(52.0)
            .refractiveIndex(1.2)
            .dispersionStrength(0.44)
            .fresnelDistanceRange(340.0)
            .fresnelIntensity(0.91)
            .fresnelEdgeSharpness(0.4)
            .glareDistanceRange(220.0)
            .glareAngleConvergence(1.4)
            .glareOppositeSideBias(0.8)
            .glareIntensity(0.67)
            .glareEdgeSharpness(0.3)
            .glareDirectionOffset(0.42)
            .tint(.mint.opacity(0.5))

        #expect(updated.blurRadius == 14.0)
        #expect(updated.glassTintStrength == 0.33)
        #expect(updated.edgeShadowStrength == 0.05)
        #expect(updated.cornerRoundnessExponent == 5.5)
        #expect(updated.glassThickness == 52.0)
        #expect(updated.refractiveIndex == 1.2)
        #expect(updated.dispersionStrength == 0.44)
        #expect(updated.fresnelDistanceRange == 340.0)
        #expect(updated.fresnelIntensity == 0.91)
        #expect(updated.fresnelEdgeSharpness == 0.4)
        #expect(updated.glareDistanceRange == 220.0)
        #expect(updated.glareAngleConvergence == 1.4)
        #expect(updated.glareOppositeSideBias == 0.8)
        #expect(updated.glareIntensity == 0.67)
        #expect(updated.glareEdgeSharpness == 0.3)
        #expect(updated.glareDirectionOffset == 0.42)
        #expect(updated.tintColor == .mint.opacity(0.5))

        #expect(base.blurRadius != updated.blurRadius)
        #expect(base.glassThickness != updated.glassThickness)
        #expect(base.glareDirectionOffset != updated.glareDirectionOffset)
        #expect(base.cornerRadius == updated.cornerRadius)
        #expect(base.opacity == updated.opacity)
    }

    @Test
    func tessellatorPacksAdvancedLiquidGlassParametersIntoVertices() throws {
        let config = Glass.regular
            .blurRadius(11.0)
            .glassTintStrength(0.61)
            .glassThickness(42.0)
            .refractiveIndex(1.18)
            .dispersionStrength(0.27)
            .edgeShadowStrength(0.01)
            .fresnelDistanceRange(310.0)
            .fresnelIntensity(0.55)
            .fresnelEdgeSharpness(0.12)
            .glareDistanceRange(205.0)
            .glareAngleConvergence(0.88)
            .glareOppositeSideBias(1.31)
            .glareIntensity(0.47)
            .glareEdgeSharpness(0.16)
            .glareDirectionOffset(-0.21)
            .tint(.orange.opacity(0.4))

        let tessellator = UITessellator()
        let vertices = tessellator.tessellateGlassQuad(
            transform: .identity,
            halfSize: Vector2(120, 36),
            configuration: config,
            scaleFactor: 2.0
        )

        #expect(vertices.count == 4)

        let first = try #require(vertices.first)
        #expect(first.color == .orange.opacity(0.4))
        #expect(first.glassParams0 == Vector4(11.0, config.cornerRadius, 0.61, 0.01))
        #expect(first.glassParams1 == Vector4(config.cornerRoundnessExponent, 42.0, 1.18, 0.27))
        #expect(first.glassParams2 == Vector4(310.0, 0.55, 0.12, 205.0))
        #expect(first.glassParams3 == Vector4(0.88, 1.31, 0.47, 0.16))
        #expect(first.glassInfo0 == Vector4(120.0, 36.0, 2.0, config.opacity))
        #expect(first.glassInfo1 == Vector4(-0.21, 0.0, 0.0, 0.0))
    }
}
