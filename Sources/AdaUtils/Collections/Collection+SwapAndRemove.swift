//
//  Sequence+SwapAndRemove.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 16.11.2025.
//

public extension Array {
    /// Removes an element from the array and returns it.
    ///
    /// # Examples
    ///
    /// ```swift
    /// var array = Array<String>["foo", "bar", "baz", "qux"];
    ///
    /// assert(array.swapRemove(at: 1) == "bar")
    /// assert(array == ["foo", "qux", "baz"])
    ///
    /// assert(array.swapRemove(at: 0) == "foo")
    /// assert(array == ["baz", "qux"])
    /// ```
    @discardableResult
    mutating func swapRemove(at index: Int) -> Element {
        let length = self.count
        precondition(index <= length, "swapRemove index is \(index) should be < len (is \(length))")
        let tmp = self[index]
        self[index] = self[length - 1]
        self[length - 1] = tmp
        return self.removeLast()
    }
}

public extension ContiguousArray {
    /// Removes an element from the array and returns it.
    ///
    /// # Examples
    ///
    /// ```swift
    /// var array = ContiguousArray<String>["foo", "bar", "baz", "qux"];
    ///
    /// assert(array.swapRemove(at: 1) == "bar")
    /// assert(array == ["foo", "qux", "baz"])
    ///
    /// assert(array.swapRemove(at: 0) == "foo")
    /// assert(array == ["baz", "qux"])
    /// ```
    @discardableResult
    mutating func swapRemove(at index: Int) -> Element {
        let length = self.count
        precondition(index <= length, "swapRemove index is \(index) should be < len (is \(length))")
        let tmp = self[index]
        self[index] = self[length - 1]
        self[length - 1] = tmp
        return self.removeLast()
    }
}
