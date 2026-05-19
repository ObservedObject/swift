// RUN: %target-run-simple-swift(-disable-experimental-parser-round-trip) | %FileCheck %s
// REQUIRES: executable_test

subtypealias Kelvin = Double
subtypealias Celsius = Kelvin
subtypealias Fahrenheit = Double

protocol P {
  func pr()
}

extension Celsius: P {
  func pr() {
    print("celsius.pr")
  }
}

func acceptProtocol(_ p: any P) {
  p.pr()
  print("P")
}

let temperature: Celsius = 100.0
acceptProtocol(temperature)

// CHECK: celsius.pr
// CHECK-NEXT: P

print(type(of: temperature) == Celsius.self)
print(String(describing: type(of: temperature)))
print(String(reflecting: type(of: temperature)))
print(Mirror(reflecting: temperature).subjectType)

// CHECK-NEXT: true
// CHECK-NEXT: Double
// CHECK-NEXT: Swift.Double
// CHECK-NEXT: Double

subtypealias SArray = Set<Int>

extension SArray {
  var array: Array<Element> { Array(self).sorted() }
}

let values = SArray([3, 1, 2])
print(values.array)

// CHECK-NEXT: [1, 2, 3]
