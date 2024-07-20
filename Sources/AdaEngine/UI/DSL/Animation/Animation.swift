//
//  Animation.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 18.07.2024.
//

public struct AnimationContext<V: VectorArithmetic> {
    public internal(set) var environment: EnvironmentValues
}

protocol CustomAnimation: Hashable {
    /// Calculates the value of the animation at the specified time.
    /// - Parameter time: The elapsed time since the start of the animation.
    /// - Returns: The current value of the animation, or `nil` if the animation has finished.
    func animate<V: VectorArithmetic>(_ value: V, time: TimeInterval, in context: inout AnimationContext<V>) -> V?
}

struct LinearAnimation: CustomAnimation {

    let duration: TimeInterval

    func animate<V: VectorArithmetic>(_ value: V, time: TimeInterval, in context: inout AnimationContext<V>) -> V? {
        guard time < duration else {
            return nil
        }

        return value.interpolated(towards: value, amount: Double(time / duration))
    }
}

public struct Animation: Equatable, @unchecked Sendable {

    let base: any CustomAnimation

    init<T: CustomAnimation>(_ base: T) {
        self.base = base
    }

    public static func == (lhs: Animation, rhs: Animation) -> Bool {
        return lhs.base.hashValue == rhs.base.hashValue
    }
}

public extension Animation {
    static let `default`: Animation = .linear

    static let linear: Animation = .linear(duration: 0.3)

    static func linear(duration: TimeInterval) -> Animation {
        Animation(LinearAnimation(duration: duration))
    }
}

public protocol VectorArithmetic: AdditiveArithmetic {

    var magnitudeSquared: Double { get}

    mutating func scale(by rhs: Double)
}

public extension VectorArithmetic {
    /// Returns a value with each component of this value multiplied by the
    /// given value.
    func scaled(by rhs: Double) -> Self {
        var value = self
        value.scale(by: rhs)
        return value
    }

    /// Interpolates this value with `other` by the specified `amount`.
    ///
    /// This is equivalent to `self = self + (other - self) * amount`.
    mutating func interpolate(towards other: Self, amount: Double) {
        self = self.interpolated(towards: other, amount: amount)
    }

    /// Returns this value interpolated with `other` by the specified `amount`.
    ///
    /// This result is equivalent to `self + (other - self) * amount`.
    func interpolated(towards other: Self, amount: Double) -> Self {
        return self + (other - self).scaled(by: amount)
    }
}


public protocol Animatable {
    /// The type defining the data to animate.
    associatedtype AnimatableData: VectorArithmetic

    /// The data to animate.
    var animatableData: AnimatableData { get set }
}

public extension Animatable where Self : VectorArithmetic {

    /// The data to animate.
    var animatableData: Self {
        get { self }
        set { self = newValue }
    }
}

public extension Animatable where Self.AnimatableData == EmptyAnimatableData {

    /// The data to animate.
    var animatableData: EmptyAnimatableData {
        get { EmptyAnimatableData() }
        // swiftlint:disable:next unused_setter_value
        set { }
    }
}

public struct EmptyAnimatableData: VectorArithmetic {
    public static func - (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData {
        EmptyAnimatableData(value: lhs.value - rhs.value)
    }

    public static func + (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData {
        EmptyAnimatableData(value: lhs.value + rhs.value)
    }

    public static var zero: EmptyAnimatableData = EmptyAnimatableData(value: 0)

    var value: Double

    init(value: Double) {
        self.value = value
    }

    public init() {
        self.value = 0
    }

    public mutating func scale(by rhs: Double) {
        value = value * rhs
    }

    public var magnitudeSquared: Double { return 0 }
}

public extension View {
    func animation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        AnimatedView(content: self, animation: animation, value: value)
    }
}

struct AnimatedView<Content: View, Value: Equatable>: View, ViewNodeBuilder {

    typealias Body = Never

    let content: Content
    let animation: Animation
    let value: Value

    func makeViewNode(inputs: _ViewInputs) -> ViewNode {
        AnimatedViewNode(
            contentNode: inputs.makeNode(from: content),
            content: content,
            value: self.value,
            animation: animation
        )
    }

}

class AnimatedViewNode<Value: Equatable>: ViewModifierNode {
    var currentValue: Value
    let animation: Animation

    var currentAnimationTime: TimeInterval = 0
    var currentAnimationValue: Double = 0
    var isPlaying: Bool = false
    var currentAnimationContext: AnimationContext<Double>?

    init<Content: View>(contentNode: ViewNode, content: Content, value: Value, animation: Animation) {
        self.currentValue = value
        self.animation = animation
        super.init(contentNode: contentNode, content: content)
    }

    override func merge(_ otherNode: ViewNode) {
        super.merge(otherNode)

        guard let node = otherNode as? Self else {
            return
        }

        // Update current stored value and notify about that
        if node.currentValue != self.currentValue {
            self.playAnimation()
            self.currentValue = node.currentValue
        }
    }

    private func playAnimation() {
        if isPlaying {
            return
        }

        self.currentAnimationValue = 0
        self.currentAnimationContext = AnimationContext(environment: self.environment)
        self.currentAnimationTime = 0
        self.isPlaying = true
    }

    private func stopAnimation() {
        self.isPlaying = false
    }

    override func update(_ deltaTime: TimeInterval) async {
        guard var currentAnimationContext, isPlaying else {
            return
        }

        if let value = self.animation.base.animate(currentAnimationValue, time: currentAnimationTime, in: &currentAnimationContext) {
            self.contentNode.invalidateContent()
            self.currentAnimationValue = value

            self.currentAnimationContext = currentAnimationContext
            self.currentAnimationTime += deltaTime
        } else {
            self.stopAnimation()
        }
    }
}

extension Double: VectorArithmetic {
    public var magnitudeSquared: Double {
        self * self
    }
    
    public mutating func scale(by rhs: Double) {
        self *= self
    }
}

extension Float: VectorArithmetic {
    public var magnitudeSquared: Double {
        Double(self * self)
    }

    public mutating func scale(by rhs: Double) {
        self *= Float(self)
    }
}

public struct Transaction {

    public init() { }

    public init(animation: Animation? = nil) {
        self.animation = animation
    }

    public var animation: Animation?

    public var disablesAnimations: Bool = false
}

final class TransactionController {

    static let shared = TransactionController()

    enum TransactionState {
        case idle
        case playing
        case done
    }

    struct TransactionItem {
        let transaction: Transaction
        let valueFrom: Any
        let valueTo: Any
        var state: TransactionState
    }

    var pendingTransactions: [Transaction] = []
    var currentTransactions: [TransactionItem] = []

    func update(_ deltaTime: TimeInterval) {
        
    }

    func addTransaction(_ transaction: Transaction) {
        self.pendingTransactions.append(transaction)
    }
}

class Tween<Value: VectorArithmetic> {
    let valueFrom: Value
    let valueTo: Value
    let animation: Animation

    init(valueFrom: Value, valueTo: Value, animation: Animation) {
        self.valueFrom = valueFrom
        self.valueTo = valueTo
        self.animation = animation
    }

    func update(_ deltaTime: TimeInterval) {
        
    }
}

extension EnvironmentValues {
    @Entry var transactionController: TransactionController?
}
