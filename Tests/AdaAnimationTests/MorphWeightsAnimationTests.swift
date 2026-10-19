import AdaAnimation
import Math
import Testing

@Suite
struct MorphWeightsAnimationTests {
    // MARK: Tracks

    @Test
    func samplesLinearAndStepWeightsAndClampsAtTheEnds() throws {
        let linear = try MorphWeightsTrack(nodeIndex: 0, interpolation: .linear, times: [0, 1], targetCount: 2, values: [0, 1, 1, 0.5])
        var output: [Float] = [9, 9]
        linear.sample(at: -3, into: &output)
        #expect(output == [0, 1])
        linear.sample(at: 0.5, into: &output)
        #expect(output == [0.5, 0.75])
        linear.sample(at: 4, into: &output)
        #expect(output == [1, 0.5])
        let step = try MorphWeightsTrack(nodeIndex: 0, interpolation: .step, times: [0, 1], targetCount: 2, values: [0, 1, 1, 0.5])
        step.sample(at: 0.99, into: &output)
        #expect(output == [0, 1])
        step.sample(at: 1, into: &output)
        #expect(output == [1, 0.5])
    }

    @Test
    func cubicWeightsUseTangentsScaledByTheKeySpan() throws {
        // Two targets, two keys 2 seconds apart. Per key: in-tangent, value, out-tangent (each of both targets).
        let values: [Float] = [
            0, 0, /* in */ 0, 0, /* value */ 0, 0, /* out */
            0, 0, /* in */ 1, 4, /* value */ 0, 0, /* out */
        ]
        let cubic = try MorphWeightsTrack(nodeIndex: 0, interpolation: .cubicSpline, times: [0, 2], targetCount: 2, values: values)
        var output: [Float] = [0, 0]
        cubic.sample(at: 1, into: &output)
        #expect(abs(output[0] - 0.5) < 0.00001 && abs(output[1] - 2) < 0.00001, "Flat tangents give the smoothstep midpoint.")
        let sloped: [Float] = [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]
        let withTangent = try MorphWeightsTrack(nodeIndex: 0, interpolation: .cubicSpline, times: [0, 2], targetCount: 2, values: sloped)
        withTangent.sample(at: 1, into: &output)
        #expect(abs(output[0] - 0.25) < 0.00001, "An out-tangent of 1 over a 2 second span adds a quarter at the midpoint.")
    }

    @Test(arguments: ["noTargets", "noKeys", "times", "valueCount", "nonFinite", "cubicNeedsTwoKeys", "negativeNode"])
    func rejectsInvalidTracks(kind: String) {
        #expect(throws: SkeletalAnimationError.invalidTrack) {
            switch kind {
            case "noTargets": _ = try MorphWeightsTrack(nodeIndex: 0, interpolation: .linear, times: [0], targetCount: 0, values: [])
            case "noKeys": _ = try MorphWeightsTrack(nodeIndex: 0, interpolation: .linear, times: [], targetCount: 1, values: [])
            case "times": _ = try MorphWeightsTrack(nodeIndex: 0, interpolation: .linear, times: [1, 1], targetCount: 1, values: [0, 1])
            case "valueCount": _ = try MorphWeightsTrack(nodeIndex: 0, interpolation: .linear, times: [0, 1], targetCount: 2, values: [0, 1, 2])
            case "nonFinite": _ = try MorphWeightsTrack(nodeIndex: 0, interpolation: .linear, times: [0], targetCount: 1, values: [.nan])
            case "cubicNeedsTwoKeys": _ = try MorphWeightsTrack(nodeIndex: 0, interpolation: .cubicSpline, times: [0], targetCount: 1, values: [0, 0, 0])
            default: _ = try MorphWeightsTrack(nodeIndex: -1, interpolation: .linear, times: [0], targetCount: 1, values: [0])
            }
        }
    }

    // MARK: Player

    /// Node 0 carries a mesh with two targets resting at [0.2, 0.4]; node 1 has no morph targets.
    private func makeRig() throws -> SkeletalRig {
        try SkeletalRig(nodes: [
            .init(parentIndex: nil, restPose: SkeletalJointPose(), restMatrix: .identity, morphRestWeights: [0.2, 0.4]),
            .init(parentIndex: 0, restPose: SkeletalJointPose(), restMatrix: .identity),
        ])
    }

    private func clip(_ name: String, from: [Float], to: [Float], duration: Double = 1) throws -> SkeletalAnimationClip {
        SkeletalAnimationClip(name: name, tracks: [], morphTracks: [
            try MorphWeightsTrack(nodeIndex: 0, interpolation: .linear, times: [0, duration], targetCount: 2, values: from + to),
        ])
    }

    private func makePlayer() throws -> SkeletalAnimationPlayer {
        try SkeletalAnimationPlayer(rig: makeRig(), clips: [clip("Open", from: [0, 0], to: [1, 0.5]), clip("Close", from: [1, 1], to: [1, 1])])
    }

    @Test
    func weightsStartAtTheRestWeightsAndOnlyMorphNodesHaveThem() throws {
        let player = try makePlayer()
        #expect(player.morphWeights == [[0.2, 0.4], []])
    }

    @Test
    func aPlayingClipDrivesTheWeights() throws {
        var player = try makePlayer()
        try player.play("Open", transitionDuration: 0)
        #expect(player.morphWeights[0] == [0, 0])
        player.seek(to: 0.5)
        #expect(player.morphWeights[0] == [0.5, 0.25])
        player.advance(by: 0.25)
        #expect(player.morphWeights[0] == [0.75, 0.375])
        #expect(player.morphWeights[1].isEmpty)
        // The clip loops: 1.25 seconds in is 0.25 into the next cycle.
        player.seek(to: 1.25)
        #expect(player.morphWeights[0] == [0.25, 0.125])
        player.repeats = false
        player.seek(to: 7)
        #expect(player.morphWeights[0] == [1, 0.5], "A clip that does not repeat holds its last weights.")
    }

    @Test
    func playersKeepIndependentWeights() throws {
        var first = try makePlayer()
        let second = first
        try first.play("Open", transitionDuration: 0)
        first.repeats = false
        first.seek(to: 1)
        #expect(first.morphWeights[0] == [1, 0.5] && second.morphWeights[0] == [0.2, 0.4])
    }

    @Test
    func aTransitionCrossfadesFromThePreviousWeights() throws {
        var player = try makePlayer()
        try player.play("Open", transitionDuration: 0)
        player.repeats = false
        player.seek(to: 1)
        #expect(player.morphWeights[0] == [1, 0.5])
        try player.play("Close", transitionDuration: 1)
        #expect(player.morphWeights[0] == [1, 0.5], "A fade that has not started shows the old weights.")
        player.advance(by: 0.5)
        #expect(abs(player.morphWeights[0][0] - 1) < 0.00001 && abs(player.morphWeights[0][1] - 0.75) < 0.00001)
        player.advance(by: 1)
        #expect(player.morphWeights[0] == [1, 1])
    }

    @Test
    func tracksMustAddressNodesWithMatchingTargetCounts() throws {
        let rig = try makeRig()
        let wrongNode = SkeletalAnimationClip(name: "Bad", tracks: [], morphTracks: [
            try MorphWeightsTrack(nodeIndex: 1, interpolation: .linear, times: [0], targetCount: 2, values: [0, 0]),
        ])
        #expect(throws: SkeletalAnimationError.invalidTrack) { try SkeletalAnimationPlayer(rig: rig, clips: [wrongNode]) }
        let wrongCount = SkeletalAnimationClip(name: "Bad", tracks: [], morphTracks: [
            try MorphWeightsTrack(nodeIndex: 0, interpolation: .linear, times: [0], targetCount: 3, values: [0, 0, 0]),
        ])
        #expect(throws: SkeletalAnimationError.invalidTrack) { try SkeletalAnimationPlayer(rig: rig, clips: [wrongCount]) }
    }

    @Test
    func onlyNodesSomeClipAnimatesAreReportedAsAnimated() throws {
        #expect(try makePlayer().animatedMorphNodes == [0])
        let still = try SkeletalAnimationPlayer(rig: makeRig(), clips: [SkeletalAnimationClip(name: "Still", tracks: [])])
        #expect(still.animatedMorphNodes.isEmpty, "A rig whose clips animate no weights must leave entity weights alone.")
    }

    @Test
    func weightTracksCountTowardTheClipDuration() throws {
        #expect(try clip("Long", from: [0, 0], to: [1, 1], duration: 2.5).duration == 2.5)
    }

    // MARK: Graph

    @Test
    func aBlendNodeMixesWeightsLikePoses() throws {
        var player = try makePlayer()
        let graph = AnimationGraph(root: "Mix", nodes: [
            .init(id: "Open", clip: "Open"), .init(id: "Close", clip: "Close"),
            .init(id: "Mix", kind: .blend, inputs: [.init(node: "Open", weight: 0.75), .init(node: "Close", weight: 0.25)]),
        ])
        try player.play(graph, transitionDuration: 0)
        player.seek(to: 0.5)
        // Open at 0.5 is [0.5, 0.25] and Close is [1, 1].
        #expect(abs(player.morphWeights[0][0] - (0.5 * 0.75 + 1 * 0.25)) < 0.00001)
        #expect(abs(player.morphWeights[0][1] - (0.25 * 0.75 + 1 * 0.25)) < 0.00001)
        // Weights that add up to less than one let the rest weights fill the gap.
        try player.setGraphWeight(0.5, node: "Mix", input: 0)
        try player.setGraphWeight(0, node: "Mix", input: 1)
        #expect(abs(player.morphWeights[0][0] - (0.5 * 0.5 + 0.2 * 0.5)) < 0.00001)
    }

    @Test
    func aMaskOnTheMeshNodeScalesItsWeights() throws {
        var player = try makePlayer()
        let graph = AnimationGraph(root: "Mix", nodes: [
            .init(id: "Open", clip: "Open"), .init(id: "Close", clip: "Close"),
            .init(id: "Mix", kind: .blend, inputs: [
                .init(node: "Open"),
                // The second input only reaches node 1, so it must leave the weights of node 0 alone.
                .init(node: "Close", mask: .init(joints: [.init(nodeIndex: 1, includesDescendants: false)])),
            ]),
        ])
        try player.play(graph, transitionDuration: 0)
        player.seek(to: 0.5)
        #expect(abs(player.morphWeights[0][0] - 0.5) < 0.00001 && abs(player.morphWeights[0][1] - 0.25) < 0.00001)
    }

    @Test
    func anAdditiveNodeAddsOffsetsFromTheRestWeights() throws {
        var player = try makePlayer()
        let graph = AnimationGraph(root: "Layer", nodes: [
            .init(id: "Base", clip: "Open"), .init(id: "Extra", clip: "Close"),
            .init(id: "Layer", kind: .additive, inputs: [.init(node: "Base"), .init(node: "Extra", weight: 0.5)]),
        ])
        try player.play(graph, transitionDuration: 0)
        player.seek(to: 0.5)
        // Base [0.5, 0.25]; Extra [1, 1] is [0.8, 0.6] above the rest weights [0.2, 0.4], half of which is added.
        #expect(abs(player.morphWeights[0][0] - (0.5 + 0.8 * 0.5)) < 0.00001)
        #expect(abs(player.morphWeights[0][1] - (0.25 + 0.6 * 0.5)) < 0.00001)
    }

    @Test
    func aClipWithoutWeightTracksLeavesTheRestWeights() throws {
        var player = try SkeletalAnimationPlayer(
            rig: makeRig(),
            clips: [SkeletalAnimationClip(name: "Still", tracks: [
                try SkeletalAnimationTrack(nodeIndex: 1, path: .translation, interpolation: .linear, times: [0, 1], values: [.zero, [1, 0, 0, 0]]),
            ])]
        )
        try player.play("Still", transitionDuration: 0)
        player.seek(to: 0.5)
        #expect(player.morphWeights[0] == [0.2, 0.4])
    }
}
