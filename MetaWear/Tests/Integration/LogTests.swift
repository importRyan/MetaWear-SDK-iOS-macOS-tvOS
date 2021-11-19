// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import XCTest
import Combine
@testable import MetaWear
@testable import MetaWearCpp

class LogTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestDevices.useOnly(.S_A4)
    }

    func test_LogThenDownload_OneSensor_Accelerometer() {
        let sut: some MWLoggable = .accelerometer(rate: .hz12_5, gravity: .g2)

        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            metawear.publish()
                ._assertLoggers([], metawear: metawear)
                .log(sut)
                ._assertLoggers([sut.loggerName], metawear: metawear)
                .share()
                .delay(for: 1, tolerance: 0, scheduler: metawear.apiAccessQueue)
                .logDownload(sut)

            // Assert
                .handleEvents(receiveOutput: { data, percentComplete in
                    _printProgress(percentComplete)
                    if percentComplete < 1 { XCTAssertTrue(data.isEmpty) }
                    guard percentComplete == 1.0 else { return }
                    XCTAssertGreaterThan(data.endIndex, 0)
                })
                .drop(while: { $0.percentComplete < 1 })
                ._assertLoggers([], metawear: metawear)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func test_LogThenDownload_TwoSensors_AccelerometerMagnetometer() {
        let sut1: some MWLoggable = .accelerometer(rate: .hz50, gravity: .g2)
        let sut2: some MWLoggable = .magnetometer(freq: .hz25)

        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            metawear.publish()
                ._assertLoggers([], metawear: metawear)
                .log(sut1)
                .log(sut2)
                ._assertLoggers([sut1.loggerName, sut2.loggerName], metawear: metawear)
                .share()
                .delay(for: 1, tolerance: 0, scheduler: metawear.apiAccessQueue)
                .logsDownload()

            // Assert
                .handleEvents(receiveOutput: { tables, percentComplete in
                    _printProgress(percentComplete)
                    if percentComplete < 1 { XCTAssertTrue(tables.isEmpty) }
                    guard percentComplete == 1 else { return }
                    XCTAssertEqual(tables.endIndex, 2)
                    XCTAssertEqual(Set(tables.map(\.source)), Set([sut1.loggerName, sut2.loggerName]))
                    XCTAssertTrue(tables.allSatisfy({ $0.rows.isEmpty == false }))
                })
                .drop(while: { $0.percentComplete < 1 })
                ._assertLoggers([], metawear: metawear)
                ._sinkNoFailure(&subs, receiveValue: { _ in exp.fulfill() })
        }
    }

    func test_Read_LogLength_WhenCleared() {
        connectNearbyMetaWear(timeout: .read, useLogger: false) { metawear, exp, subs in
            // Prepare
            metawear.publish()
                .deleteLoggedEntries()
                .delay(for: 1, tolerance: 0, scheduler: metawear.apiAccessQueue)

            // Act
                .read(signal: .logLength)

            // Assert
                ._sinkNoFailure(&subs, receiveValue: {
                    XCTAssertEqual($0.value, 0)
                    exp.fulfill()
                })
        }
    }

    func test_Read_LogLength_WhenPopulated() {
        let log: some MWLoggable = .accelerometer(rate: .hz50, gravity: .g2)

        connectNearbyMetaWear(timeout: .download, useLogger: false) { metawear, exp, subs in
            // Prepare
            metawear.publish()
                .deleteLoggedEntries()
                .delay(for: 5, tolerance: 0, scheduler: metawear.apiAccessQueue)
                .log(log)
                ._assertLoggers([log.loggerName], metawear: metawear)
                .delay(for: 10, tolerance: 0, scheduler: metawear.apiAccessQueue)

            // Act
                .read(signal: .logLength)

            // Assert
                ._sinkNoFailure(&subs, receiveValue: {
                    XCTAssertGreaterThan($0.value, 1)
                    metawear.resetToFactoryDefaults()
                    exp.fulfill()
                })
        }
    }
}
