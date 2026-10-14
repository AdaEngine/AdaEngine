/// One `@test` function discovered in an Ada Script module (ADR-0024).
public struct AdaScriptTestCase: Sendable, Equatable, Hashable {
    /// The string given to `@test("…")`, or the function name.
    public let displayName: String
    /// The line of the `func` keyword, starting at 1.
    public let line: Int
    public let name: String
    public let path: String
}

/// The outcome of running one `@test` function.
public struct AdaScriptTestResult: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable {
        case failed
        case passed
    }

    public let test: AdaScriptTestCase
    /// Failed expectations as `path:line:column: message`, then any runtime errors the test raised.
    public let diagnostics: [String]
    public let duration: Duration
    public let outcome: Outcome

    init(test: AdaScriptTestCase, execution: AdaScriptTestExecution, duration: Duration) {
        var diagnostics = execution.failures + execution.runtimeErrors
        if execution.didAbort && diagnostics.isEmpty {
            diagnostics = ["\(test.path):\(test.line): test aborted"]
        }
        self.test = test
        self.diagnostics = diagnostics
        self.duration = duration
        self.outcome = diagnostics.isEmpty ? .passed : .failed
    }
}

/// What the VM reported for one test run.
struct AdaScriptTestExecution: Sendable {
    var failures: [String]
    var runtimeErrors: [String]
    /// The test's fiber ended with an error: a failed `require` or a runtime error.
    var didAbort: Bool
}

/// The assertions available to `@test` functions. Calls reach them through `AdaScriptTestLowerer`, which
/// prepends the call-site location as the first argument.
enum AdaScriptTestPrelude {
    static let source = """
    extern var __adaTestFactory;
    var __adaTestFailures = [];

    func TestWorld() { return __adaTestFactory.make(); }

    func __adaTest_expect(location, condition) {
        if (!condition) { __adaTestFailures.push(location + ": expectation failed"); }
    }

    func __adaTest_expectEqual(location, actual, expected) {
        if (actual != expected) {
            __adaTestFailures.push(location + ": expected \\(expected) but got \\(actual)");
        }
    }

    func __adaTest_expectNear(location, actual, expected, tolerance = 0.0001) {
        var difference = actual - expected;
        if (difference < 0) { difference = 0 - difference; }
        if (difference > tolerance) {
            __adaTestFailures.push(location + ": expected \\(expected) within \\(tolerance) but got \\(actual)");
        }
    }

    func __adaTest_expectNil(location, value) {
        if (value != null) { __adaTestFailures.push(location + ": expected null but got \\(value)"); }
    }

    func __adaTest_fail(location, message = "failed") {
        __adaTestFailures.push(location + ": " + message);
    }

    func __adaTest_require(location, condition) {
        if (!condition) {
            __adaTestFailures.push(location + ": requirement failed");
            Fiber.yield();
        }
    }

    func __adaTestRun(body) {
        __adaTestFailures = [];
        var fiber = Fiber.create(body);
        fiber.try();
        return [fiber.status(), __adaTestFailures];
    }
    """
}
