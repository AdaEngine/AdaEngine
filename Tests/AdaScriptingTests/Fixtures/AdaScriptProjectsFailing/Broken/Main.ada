@test("passes")
func passes() { expect(true); }

@test("fails on purpose")
func failsOnPurpose() { expectEqual(1 + 1, 3); }
