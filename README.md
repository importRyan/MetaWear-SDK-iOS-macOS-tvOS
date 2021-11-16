# MetaWear Swift Combine SDK by MBIENTLAB

[![License](https://img.shields.io/cocoapods/l/MetaWear.svg?style=flat)](https://github.com/mbientlab/MetaWear-SDK-iOS-macOS-tvOS/blob/master/LICENSE.md)
![Screenshot](https://raw.githubusercontent.com/mbientlab/MetaWear-SDK-iOS-macOS-tvOS/master/Images/Metawear.png)

Create iOS, macOS, watchOS, and tvOS apps with MetaWear Bluetooth Low Energy 4.0/5.0 wearable sensors, regardless of prior Bluetooth experience.

This SDK wraps Combine and type-safe operators around the [MetaWear C++ API](https://github.com/mbientlab/MetaWear-SDK-Cpp) for fast development with modern asynchronous Swift. While flexible for experienced developers, this SDK also abstracts much of CoreBluetooth and C++ so anyone who knows Swift can start regardless of experience.

We also offer a Facebook Bolts-based Swift SDK, distributed via Cocoapods, for all Apple platforms.


## Sample Usage

// Stream accelerometer + calculate moving axis average on first connection
```swift
device
    .publishWhenConnected()
    .first()
    .stream(.accelerometer(range: .g2, rate: .hz100))
    .map(\.value.y)
    .collect(.byTimeOrCount(RunLoop.current, .seconds(1), 100))
    .map { $0.reduce(0,+) / Swift.max(1, Float($0.endIndex)) }
    .receive(on: DispatchQueue.main)
    .sink { completion in
        // Handle error or termination
    } receiveValue: { [weak self] zSmoothed in
        self?.z = zSmoothed
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
    .connectPublisher()
    .flashDiscoveryLED(for: delegate) 
    .saveBoardState()
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
Behaviors are nearly identical. Combine is more convenient for data streams, but delegate patterns are retained where useful. 

The SDK's publishers are almost exclusively `PassthroughSubject`, which as a class shares reference semantics with a Bolts `Task`. (Most Combine publishers are structs.)

** Differences **
1. New code-completion friendly APIs abstract away handling any `OpaquePointer` for board signals, type casting from C++, module parameters, or characteristic CBUUID handling
2. Documentation builds in Xcode 13 documentation browser (see exception below)
3. Multiple subscribers can watch a device's connection state (vs. prior single callback)
4. Eliminates `ScannerModel` and `ScannerModelItem` as publishers and operators on `MetaWearScanner` and `MetaWear` work well for `DiffableDataSource` and `SwiftUI`
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
You can try our [Combine-specific tutorial series]() and [barebones sample app]().

Our [MetaBase universal app]() for easy setup of logging and streaming sessions also uses this SDK [source](), but is obviously cluttered with more UI code.

You can also read the C++ API reference and documentation for details about what this SDK calls on. Prior Swift tutorials are still relevant for C++, but will have some Bolts operators that look a little different from Combine. 

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
