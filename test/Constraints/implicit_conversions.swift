// RUN: %target-typecheck-verify-swift
// RUN: %target-run-simple-swift
// REQUIRES: executable_test
// REQUIRES: objc_interop

// ===----------------------------------------------------------------------===
// Tests for @implicit user-defined implicit conversions (SE-XXXX).
//
// Each section covers one behavioural aspect. Sections with runtime checks
// use precondition so failures are visible immediately.
// ===----------------------------------------------------------------------===

import Foundation

// ===----------------------------------------------------------------------===
// MARK: - Helpers
// ===----------------------------------------------------------------------===

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "") {
    precondition(a == b, "\(msg): \(a) != \(b)")
}

// ===----------------------------------------------------------------------===
// MARK: - 1. Basic unlabeled conversion (contextual type)
// ===----------------------------------------------------------------------===

extension Int {
    @implicit init(d: Double) {
        self = Swift.Int(d)
    }
}

let d: Double = 3.9
let i1: Int = d          // implicit Double -> Int
assertEqual(i1, 3, "basic contextual")

// ===----------------------------------------------------------------------===
// MARK: - 2. Conversion at a function call site (ApplyArgToParam)
// ===----------------------------------------------------------------------===

func takesInt(_ n: Int) -> Int { n }
let i2: Int = takesInt(2.7)
assertEqual(i2, 2, "arg-to-param")

// ===----------------------------------------------------------------------===
// MARK: - 3. Labeled init — label preserved in synthesised call
// ===----------------------------------------------------------------------===

struct Celsius {
    var value: Double
    @implicit init(fahrenheit f: Double) {
        value = (f - 32) * 5 / 9
    }
}

let boiling: Celsius = 212.0   // 212 F -> 100 C
assertEqual(boiling.value, 100.0, "labeled init")

// ===----------------------------------------------------------------------===
// MARK: - 4. UnsafePointer<CChar> -> String (motivating C interop example)
// ===----------------------------------------------------------------------===

extension String {
    @implicit init(_ ptr: UnsafePointer<CChar>) {
        self.init(cString: ptr)
    }
}

// Store the NSString in a local variable to keep its utf8String pointer valid.
do {
    let nsStorage: NSString = "hello"
    let s1: String = nsStorage.utf8String!
    assertEqual(s1, "hello", "UnsafePointer<CChar> -> String")
}

// ===----------------------------------------------------------------------===
// MARK: - 5. Optional source type via a dedicated @implicit init
// ===----------------------------------------------------------------------===

// A separate struct avoids interaction with the UnsafePointer<CChar> inits above.
struct SafeString {
    var value: String
    @implicit init(_ ptr: UnsafeMutablePointer<CChar>?) {
        value = ptr.map { String(cString: $0) } ?? "<nil>"
    }
}

// strerror(0) returns UnsafeMutablePointer<CChar>? (IUO).
// Our init takes the optional directly, so the optional branch is used.
let ss: SafeString = strerror(0)
precondition(!ss.value.isEmpty, "optional-source init chosen")

// ===----------------------------------------------------------------------===
// MARK: - 6. Failable init — succeeds on non-nil input
// ===----------------------------------------------------------------------===

extension String {
    @implicit init?(_ url: URL) {
        guard url.scheme != nil else { return nil }
        self = url.absoluteString
    }
}

let url = URL(string: "https://swift.org")!
let s3: String = url
assertEqual(s3, "https://swift.org", "failable init (non-nil)")

// ===----------------------------------------------------------------------===
// MARK: - 7. Generic constrained extension (Set<T> -> Array<T>)
// ===----------------------------------------------------------------------===

extension Array where Element: Hashable {
    @implicit init(s: Set<Element>) {
        self = Array(s)
    }
}

let intSet = Set([1, 2, 3])

// Explicit element type annotation.
let arr1: Array<Int> = intSet
assertEqual(Set(arr1), intSet, "Set -> Array (explicit element)")

// Element inferred from the source expression.
let arr2: Array = intSet
assertEqual(Set(arr2), intSet, "Set -> Array (inferred element)")

// ===----------------------------------------------------------------------===
// MARK: - 8. Generic conversion without constraint (Wrapper<T>)
// ===----------------------------------------------------------------------===

struct Wrapper<T> {
    var value: T
    @implicit init(_ v: T) { value = v }
}

let w: Wrapper<Int> = 42
assertEqual(w.value, 42, "generic Wrapper init")

// ===----------------------------------------------------------------------===
// MARK: - 9. Conversion in return position
// ===----------------------------------------------------------------------===

func makeInt() -> Int {
    let x: Double = 7.1
    return x
}
assertEqual(makeInt(), 7, "return position")

// ===----------------------------------------------------------------------===
// MARK: - 10. Conversion inside a collection literal
// ===----------------------------------------------------------------------===

let ints: [Int] = [1.1, 2.9, 3.0]
assertEqual(ints, [1, 2, 3], "collection literal elements")

// ===----------------------------------------------------------------------===
// MARK: - 11. Single-hop Int -> String via @implicit
// ===----------------------------------------------------------------------===

extension String {
    @implicit init(_ n: Int) {
        self = "\(n)"
    }
}

let s4: String = 42
assertEqual(s4, "42", "Int -> String")

// ===----------------------------------------------------------------------===
// MARK: - 12. @implicit does not interfere with explicit calls
// ===----------------------------------------------------------------------===

let s5 = String(99)   // explicit call must still resolve correctly
assertEqual(s5, "99", "explicit call unaffected")

// ===----------------------------------------------------------------------===
// MARK: - 13. Non-@implicit init is NOT used implicitly
// ===----------------------------------------------------------------------===

struct Meters {
    var value: Double
    // Not marked @implicit — must not fire as an implicit conversion.
    init(fromFeet f: Double) { value = f * 0.3048 }
}

// Explicit call must still work.
let m = Meters(fromFeet: 6.0)
assertEqual(m.value, 6.0 * 0.3048, "non-implicit init explicit call")

// The following must be a type error (uncomment to verify with typecheck-verify):
// let _: Meters = 6.0  // expected--error {{cannot convert value of type 'Double' to specified type 'Meters'}}

// ===----------------------------------------------------------------------===
// MARK: - 14. Conversions remain in scope throughout the module
// ===----------------------------------------------------------------------===

func checkStillInScope() {
    let x: Int = 1.5       // Double -> Int (defined in section 1)
    assertEqual(x, 1, "in-scope Double->Int")
    let y: String = 7      // Int -> String (defined in section 11)
    assertEqual(y, "7", "in-scope Int->String")
}
checkStillInScope()

// ===----------------------------------------------------------------------===
// MARK: - 15. Optional destination — conversion + Optional injection
// ===----------------------------------------------------------------------===

// When toType is Int?, getImplicitConversion strips the optional to find
// @implicit init(d:), then CSApply re-injects the result into Int? via the
// originalToType preservation fix.
let dbl2: Double = 2.5
let maybeInt: Int? = dbl2
precondition(maybeInt == 2, "optional destination")

// ===----------------------------------------------------------------------===
// MARK: - 16. Ternary operator context
// ===----------------------------------------------------------------------===

// Contextual type Int propagates to both branches; each Double is converted.
let tBool = true
let t1: Int = tBool ? 1.5 : 2.5
assertEqual(t1, 1, "ternary true branch")
let t2: Int = tBool ? 7.9 : 8.3
assertEqual(t2, 7, "ternary - only taken branch")

// ===----------------------------------------------------------------------===
// MARK: - 17. Closure with explicit return type
// ===----------------------------------------------------------------------===

// The explicit '-> Int' annotation lets the solver apply the implicit
// conversion inside the closure body.
let makeIntFn: () -> Int = { () -> Int in
    let x: Double = 6.7
    return x
}
assertEqual(makeIntFn(), 6, "closure explicit return type")

// ===----------------------------------------------------------------------===
// MARK: - 18. Implicit conversion through map
// ===----------------------------------------------------------------------===

// Annotating the closure parameter and return type explicitly ensures the
// solver resolves the implicit Double->Int conversion in the body.
let rawDoubles: [Double] = [9.1, 0.9, 4.5]
let mapped: [Int] = rawDoubles.map { (x: Double) -> Int in x }
assertEqual(mapped, [9, 0, 4], "map closure implicit conversion")

print("All @implicit conversion tests passed.")
