# MetaWear Swift Combine SDK by MBIENTLAB

[![License](https://img.shields.io/cocoapods/l/MetaWear.svg?style=flat)](https://github.com/mbientlab/MetaWear-SDK-iOS-macOS-tvOS/blob/master/LICENSE.md)
![Screenshot](https://raw.githubusercontent.com/mbientlab/MetaWear-SDK-iOS-macOS-tvOS/master/Images/Metawear.png)

Create iOS, macOS, watchOS, and tvOS apps with MetaWear Bluetooth Low Energy 4.0/5.0 wearable sensors, regardless of prior Bluetooth experience.

This SDK wraps Combine and type-safe operators around the [MetaWear C++ API](https://github.com/mbientlab/MetaWear-SDK-Cpp) for fast development with modern Swift. While flexible for experienced developers, this SDK also abstracts much of CoreBluetooth so non-experts can start regardless of experience. You can import it via Swift Package Manager.

We also offer a Facebook Bolts-based Swift SDK, distributed via Cocoapods, for all Apple platforms.


## Sample Usage

// Stream accelerometer + calculate moving average
```swift
device.stream(.accelerometer(rate: .hz100, range: .g2))
    .map(\.yAxis)
    .scan(5) { $0.reduce(0,+) / 5 }
    .sink { [weak self] float in 
        self?.avg = float
    }
    .store(in: &subs)
```

// Find nearby MetaWears (sans duplicates)
```swift
let scanner = MetaWearScanner()
scanner.didDiscoverUniqueDevices
    .receive(on: DispatchQueue.main)
    .sink { [weak self] devices in 
        self?.devices.append(contentsOf: devices)
    }
    .store(in: &subs)
```

// Connect to a MetaWear
```swift
let connectToken = device
    .connect()
    .flashDiscoveryLED(for: delegate) 
    .restorePriorBoardState()
    .sink(receiveCompletion: { 
        switch $0 {
            case .error(let error):   // Setup error
            case .finished:           // Disconnected by request
        }
    }, receiveValue: { metaWear in {
                                      // Connection established
    })
```

## Comparison to MetaWear Swift Bolts SDK

** Similarities **
Behaviors are nearly identical. Combine is usually more convenient for data streams, but delegate patterns are retained where useful. Our publishers are almost exclusively `PassthroughSubject`, which as a class shares reference semantics with a Bolts `Task`. (Most Combine publishers are structs.)

** Differences **
1. New code-completion friendly APIs that handle `OpaquePointers`, type casting from C++, and module parameters for you
2. Documentation builds in Xcode 13 documentation browser
3. Multiple subscribers can watch a device's connection state (vs. prior single callback)
4. Eliminates `ScannerModel` and `ScannerModelItem` due to publishers and operators on `MetaWearScanner` and `MetaWear` that work well for `DiffableDataSource` and `SwiftUI`
5. Handles remembered device metadata storage via a new `import MetaWearUserDefaults` library
6. Slight namespace differences (e.g., aspects of `FirmwareServer`)
7. Available via Swift Package Manager
8. Higher minimum iOS requirement of iOS/iPad/tvOS 13.0 or watchOS 6.0 (e.g., iPhone SE/6s, iPad Air (3rd gen), iPad mini 4, 9.7" iPad", and all Watch Series 1)
9. Higher minimum macOS requirement of 10.15 (Catalina) (e.g., mini/Air/iMac mid 2012, Mac Pro 2013, Macbook early 2015)


## Requirements
**The iOS simulator does not support Bluetooth! Test apps must run on physical iOS devices or Macs (e.g., as an iPad app).**

- [MetaWear board](https://mbientlab.com/store/)
- [Apple ID](https://appleid.apple.com/), You can start free. To distribute via the App Store, you do need a paid [Apple Developer Account](https://developer.apple.com/programs/ios/).
- Xcode 12.0 +
- A test device running macOS Catalina 10.15+, iOS 13+, iPadOS 13+, tvOS 13+ or watchOS 6+


## Learning
You can try our Combine-specific tutorial series and barebones sample app.

Our `MetaBase` universal app for easy setup of logging and streaming sessions also uses this SDK, but is obviously cluttered with a bit more UI code.

You can also read the C++ API reference and documentation for details about what this SDK calls on. Prior Swift tutorials are still relevant, but will have some Bolts operators that look a little different from Combine. 

[Tutorials](https://mbientlab.com/tutorials/)
[MetaWear API reference](https://mbientlab.com/docs/metawear/cpp/latest/globals.html)
[C++ API documentation](https://mbientlab.com/cppdocs/latest/)

[App](https://github.com/mbientlab/MetaWear-SDK-iOS-macOS-tvOS/tree/master/StarterProject)
[App](https://github.com/mbientlab/MetaWear-SDK-iOS-macOS-tvOS/tree/master/ExampleApp)

Reach out to the [community](https://mbientlab.com/community/) if you encounter any MetaWear-specific problems, or just want to chat :)

[mBientLab](https://mbientlab.com)
[Xcode](https://developer.apple.com/xcode/)
[Swift](https://developer.apple.com/swift/)

## License
See the [License](https://github.com/mbientlab/MetaWear-SDK-iOS-macOS-tvOS/blob/master/LICENSE.md)




### Usage
Require the metawear package

```swift
import MetaWear
import MetaWearCpp
```

Call Swift APIs:
```swift
device.flashLED(color: .green, intensity: 1.0)
```

Or direct CPP SDK calls:
```swift
var pattern = MblMwLedPattern(high_intensity: 31,
                              low_intensity: 31,
                              rise_time_ms: 0,
                              high_time_ms: 2000,
                              fall_time_ms: 0,
                              pulse_duration_ms: 2000,
                              delay_time_ms: 0,
                              repeat_count: 0xFF)
mbl_mw_led_stop_and_clear(device.board)
mbl_mw_led_write_pattern(device.board, &pattern, color)
mbl_mw_led_play(device.board)
```
Or a mix of both as you can see in the example below.

### Example

Here is a walkthrough to showcase a very basic connect and toggle LED operation.
```swift
MetaWearScanner.shared.startScan(allowDuplicates: true) { (device) in
    // We found a MetaWear board, see if it is close
    if device.rssi.intValue > -50 {
        // Hooray! We found a MetaWear board, so stop scanning for more
        MetaWearScanner.shared.stopScan()
        // Connect to the board we found
        device.connectAndSetup().continueWith { t in
            if let error = t.error {
                // Sorry we couldn't connect
                print(error)
            } else {
                // Hooray! We connected to a MetaWear board, so flash its LED!
                var pattern = MblMwLedPattern()
                mbl_mw_led_load_preset_pattern(&pattern, MBL_MW_LED_PRESET_PULSE)
                mbl_mw_led_stop_and_clear(device.board)
                mbl_mw_led_write_pattern(device.board, &pattern, MBL_MW_LED_COLOR_GREEN)
                mbl_mw_led_play(device.board)
            }
        }
    }
}
```

