// RUN: %target-swift-frontend -emit-sil -disable-experimental-parser-round-trip %s -o /dev/null

subtypealias Kelvin = Double
subtypealias Celsius = Kelvin

func add<T: AdditiveArithmetic>(_ x: T, _ y: T) -> T {
  x + y
}

let c: Celsius = 100.0
_ = add(c, c)
