// RUN: %target-typecheck-verify-swift -disable-experimental-parser-round-trip
// RUN: %target-run-simple-swift(-Xfrontend -disable-experimental-parser-round-trip)
// REQUIRES: executable_test

// ===----------------------------------------------------------------------===
// Tests for 'subtypealias' — a distinct one-way subtype of an existing type.
// ===----------------------------------------------------------------------===

// MARK: - Basic declarations

subtypealias Celsius = Double
subtypealias Fahrenheit = Double
subtypealias FilePath = String
subtypealias URLString = String
subtypealias NewsURL = URLString   // subtype alias of a subtype alias

// MARK: - Covariant direction: subtype -> underlying is implicit

func takesDouble(_ d: Double) -> Double { d }
func takesString(_ s: String) -> String { s }

let boiling: Celsius = 100.0
let _: Double = boiling             // Celsius -> Double ✓
let _ = takesDouble(boiling)        // Celsius as arg to Double param ✓

let path: FilePath = "/usr/bin"
let _: String = path                // FilePath -> String ✓
let _ = takesString(path)           // FilePath as arg to String param ✓

// Transitivity: subtype alias of subtype alias
let news: NewsURL = "https://swift.org"
let _: URLString = news             // NewsURL -> URLString ✓
let _: String = news                // NewsURL -> String ✓ (through URLString)

// MARK: - Current model: underlying-typed results are accepted as subtypealias values

 let _: Celsius = 100.0            // fine
 let _: Celsius = boiling + 1.0    // currently accepted
 let _: FilePath = path + "/bin"   // currently accepted

// MARK: - Current model: distinct subtypealiases of same underlying are accepted

 let _: Celsius = Fahrenheit(212.0)   // currently accepted
 let _ = takesDouble(boiling)         // ✓ fine — both go through Double

// MARK: - Explicit cast always succeeds (same underlying layout)

let d: Double = 98.6
let bodyTemp = d as! Celsius        // expected-warning {{forced cast of '.*' to same type has no effect}}

// MARK: - Runtime behaviour is correct

func assertEqual<T: Equatable>(_ a: T, _ b: T) {
    precondition(a == b, "\(a) != \(b)")
}

let c: Celsius = 100.0
assertEqual(c, 100.0)               // Celsius compared as Double ✓

func acceptsFloatLiteral<T: ExpressibleByFloatLiteral>(_: T.Type) {}
acceptsFloatLiteral(Celsius.self)    // subtypealias inherits float-literal expressibility ✓

let freezing = Celsius(floatLiteral: 32.0)
assertEqual(freezing, 32.0)

let sum: Double = boiling + 50.0    // arithmetic yields Double, not Celsius
assertEqual(sum, 150.0)

// MARK: - Extensions on subtypealias don't pollute the underlying type

extension Celsius {
    var asFahrenheit: Double { self * 9 / 5 + 32 }
}

let f = boiling.asFahrenheit
assertEqual(f, 212.0)

// A plain Double does NOT get asFahrenheit:
let bad = (100.0 as Double).asFahrenheit  // expected-error {{value of type 'Double' has no member 'asFahrenheit'}}

print("All subtypealias tests passed.")
