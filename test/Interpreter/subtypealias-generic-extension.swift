// RUN: %target-run-simple-swift(-disable-experimental-parser-round-trip) | %FileCheck %s

subtypealias SArray = Set

extension SArray {
  var array: Array { Array(self) }
}

let a = SArray([1, 2, 3])
let _: [Int] = a.array
print("ok")

// CHECK: ok
