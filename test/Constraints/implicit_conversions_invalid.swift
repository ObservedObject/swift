// RUN: %target-typecheck-verify-swift

// ===----------------------------------------------------------------------===
// Negative tests for @implicit conversions — these must be type errors.
// Run with typecheck-verify only (no execution).
// ===----------------------------------------------------------------------===

// Non-@implicit init must NOT fire as an implicit conversion.
struct Meters {
    var value: Double
    init(fromFeet f: Double) { value = f * 0.3048 }
}

let _: Meters = 6.0  // expected-error {{cannot convert value of type 'Double' to specified type 'Meters'}}

// Chaining two @implicit conversions must NOT work.
extension Int {
    @implicit init(_ d: Double) { self = Swift.Int(d) }
}
extension String {
    @implicit init(_ n: Int) { self = "\(n)" }
}

let _: String = 3.14  // expected-error {{cannot convert value of type 'Double' to specified type 'String'}}

// ===----------------------------------------------------------------------===
// @implicit throwing init must NOT fire implicitly — the synthesised call
// site has no 'try', so applying it would be unsound.
// ===----------------------------------------------------------------------===

struct ThrowingTarget {
    @implicit init(_ n: Int) throws { }
}
let _: ThrowingTarget = 42  // expected-error {{cannot convert value of type 'Int' to specified type 'ThrowingTarget'}}

// ===----------------------------------------------------------------------===
// @implicit async init must NOT fire implicitly — the synthesised call
// site has no 'await', so applying it would be unsound.
// ===----------------------------------------------------------------------===

struct AsyncTarget {
    @implicit init(_ n: Int) async { }
}
let _: AsyncTarget = 42  // expected-error {{cannot convert value of type 'Int' to specified type 'AsyncTarget'}}

// ===----------------------------------------------------------------------===
// @implicit init in a constrained extension must NOT fire when the
// extension's where-clause requirements are not satisfied for the destination
// type. The matchPriority quick-check path used to bypass checkGenericRequirements()
// for inits with a concrete parameter type.
// ===----------------------------------------------------------------------===

struct BoxedForConstraint<T> {
    var value: T
    init(value: T) { self.value = value }
}

extension BoxedForConstraint where T == String {
    @implicit init(_ s: String) { self.value = s }
}

let _: BoxedForConstraint<Int> = "hello"  // expected-error {{cannot convert value of type 'String' to specified type 'BoxedForConstraint<Int>'}}
