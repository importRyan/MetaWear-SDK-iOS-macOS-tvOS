// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import XCTest
import Combine
@testable import MetaWear
@testable import MetaWearCpp

class ReadTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestDevices.useAnyNearbyDevice()
    }

    func test_Read_Temperature() throws {
        connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
            let sut = try MWThermometer(type: .onboard, board: metawear.board, pollsPerSecond: 1)
            metawear.publish()
                .read(signal: sut)
                ._sinkNoFailure(&subs, receiveValue: { temp in
                    print(temp.value)
                    XCTAssertGreaterThan(temp.value, 0)
                    exp.fulfill()
                })
        }
    }

    func test_Read_Temperature_BMP280() throws {
        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            var modes: [MWThermometer.Source] = [.onboard, .bmp280]
            var sub: AnyCancellable? = nil

            func test() {
                guard let mode = modes.popLast() else {
                    sub?.cancel()
                    exp.fulfill()
                    return
                }
                let sut = try! MWThermometer(type: mode, board: metawear.board, pollsPerSecond: 1)
                sub = metawear
                    .publish()
                    .read(signal: sut)
                    .sink { completion in
                        guard case let .failure(error) = completion else { return }
                        XCTFail(error.localizedDescription)
                    } receiveValue: { value in
                        Swift.print("Read", value)
                        test()
                    }
            }
            test()
        }
    }
}
