// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
@testable import MetaWear
@testable import MetaWearCpp
import Combine
import CoreBluetooth

class StreamTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestDevices.useOnly(.S_A4)
    }

    func testStream_Accelerometer() {
        _testStream(.accelerometer(rate: .hz50, gravity: .g2))
    }

    func testStream_AmbientLight() {
        _testStream(.ambientLight(rate: .ms500, gain: .gain1, integrationTime: .ms100))
    }

    func testStream_BarometerAbsolute()  {
        _testStream(.absoluteAltitude(standby: .ms125, iir: .avg2, oversampling: .standard))
    }

    func testStream_BarometerRelative() {
        _testStream(.relativePressure(standby: .ms125, iir: .avg2, oversampling: .standard))
    }

    func testStream_Gyroscope() {
        _testStream(.gyroscope(range: .dps125, freq: .hz50))
    }

    func testStream_Magnetometer() {
        _testStream(.magnetometer(freq: .hz15))
    }

    // MARK: - Sensor Fusion All Modes

    func testStream_SensorFusion_EulerAngles() {
        _testStreamFusion(sut: { .sensorFusionEulerAngles(mode: $0) })
    }

    func testStream_SensorFusion_Gravity() {
        _testStreamFusion(sut: { .sensorFusionGravity(mode: $0) })
    }

    func testStream_SensorFusion_Quaternion() {
        _testStreamFusion(sut: { .sensorFusionQuaternion(mode: $0) })
    }

    func testStream_SensorFusion_LinearAcceleration() {
        _testStreamFusion(sut: { .sensorFusionLinearAcceleration(mode: $0) })
    }
}

// MARK: - Helpers

extension XCTestCase {

    func _testStream<S: MWStreamable>(_ sut: S, timeout: TimeInterval = .read) {
        connectNearbyMetaWear(timeout: timeout, useLogger: false) { metawear, exp, subs in
            var dataCount = 0
            var sub: AnyCancellable? = nil

            sub = metawear
                .publish()
                .stream(sut)
                .sink { completion in
                    guard case let .failure(error) = completion else { return }
                    XCTFail(error.localizedDescription)
                } receiveValue: { _, value in
                    dataCount += 1
                    Swift.print("Streamed", dataCount, value)

                    if dataCount == 5 {
                        sub?.cancel()
                        exp.fulfill()
                    }
                }
        }
    }

    func _testStreamFusion<S: MWStreamable>(sut: @escaping (MWSensorFusion.Mode) -> S) {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            var modes = MWSensorFusion.Mode.allCases
            var dataCount = 0
            var sub: AnyCancellable? = nil

            func test() {
                dataCount = 0
                guard let mode = modes.popLast() else {
                    exp.fulfill()
                    return
                }
                sub = metawear
                    .publish()
                    .stream(sut(mode))
                    .sink { completion in
                        guard case let .failure(error) = completion else { return }
                        XCTFail(error.localizedDescription)
                    } receiveValue: { _, value in
                        dataCount += 1
                        Swift.print("Streamed", dataCount, value)

                        if dataCount == 5 {
                            sub?.cancel()
                            test()
                        }
                    }
            }

            test()
        }
    }
}
