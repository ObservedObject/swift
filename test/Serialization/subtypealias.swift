// RUN: %target-swift-frontend -emit-module -module-name SubtypeAliasModule %s -emit-module-path %t/SubtypeAliasModule.swiftmodule -disable-experimental-parser-round-trip
// RUN: %target-swift-frontend -typecheck -I %t %s -D CLIENT -disable-experimental-parser-round-trip

#if CLIENT
import SubtypeAliasModule

let temperature: Celsius = 100.0
let _: Double = temperature
let _: Double = temperature.fahrenheit
#else
public subtypealias Kelvin = Double
public subtypealias Celsius = Kelvin

public extension Celsius {
  var fahrenheit: Double { self * 9 / 5 + 32 }
}
#endif

