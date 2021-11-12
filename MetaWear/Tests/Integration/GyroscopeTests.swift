//
//  GyroscopeTests.swift
//  MetaWear
//
//  Created by Laura Kassovic on 2/12/21.
//  Copyright © 2021 Stephen Schiffli. All rights reserved.
//

import Foundation
import XCTest
import Combine
@testable import MetaWear
@testable import MetaWearCpp

class GyroscopeTests: XCTestCase, MetaWearTestCase {
    var device: MetaWear?
    var data: [MetaWearData] = []
    var expectation: XCTestExpectation?
    var counter: Int = 0
    var handlers = MblMwLogDownloadHandler()

    // MARK: - Setup/Teardown - Discover, Connect, Disconnect

    var discovery: AnyCancellable? = nil
    var disconnectExpectation: XCTestExpectation?

    override func setUp() {
        super.setUp()
        connectToAnyNearbyMetaWear()
    }

    override func tearDown() {
        super.tearDown()
        XCTAssertNoThrow(try expectDisconnection())
    }

    func testConnection() throws {
        XCTAssertTrue(device?.isConnectedAndSetup == true)
        try prepareDeviceForTesting()
    }

    // MARK: - Tests

    func testGyroBMI160Data() throws {
        let device = try XCTUnwrap(device)
        let expectation = XCTestExpectation(description: "get gyro data")
        // Set the max range of the accelerometer
        mbl_mw_gyro_bmi160_set_range(device.board, MBL_MW_GYRO_BOSCH_RANGE_2000dps)
        mbl_mw_gyro_bmi160_set_odr(device.board, MBL_MW_GYRO_BOSCH_ODR_50Hz)
        mbl_mw_gyro_bmi160_write_config(device.board)
        // Get acc signal
        let gyroSignal = mbl_mw_gyro_bmi160_get_rotation_data_signal(device.board)
        mbl_mw_datasignal_subscribe(gyroSignal, bridge(obj: self)) { (context, dataPtr) in
            let this: GyroscopeTests = bridge(ptr: context!)
            let df = DateFormatter()
            df.dateFormat = "y-MM-dd H:m:ss.SSSS"
            let date = df.string(from: dataPtr!.pointee.timestamp) // -> "2016-11-17 17:51:15.1720"
            print(dataPtr!.pointee.epoch, date, dataPtr!.pointee.valueAs() as MblMwCartesianFloat)
            this.data.append(dataPtr!.pointee.copy())
        }
        // Start sampling and start acc
        mbl_mw_gyro_bmi160_enable_rotation_sampling(device.board)
        mbl_mw_gyro_bmi160_start(device.board)
        // Stop after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            // Stop the stream
            mbl_mw_gyro_bmi160_stop(device.board)
            mbl_mw_gyro_bmi160_disable_rotation_sampling(device.board)
            mbl_mw_datasignal_unsubscribe(gyroSignal)
            for entry in self.data {
                let pt: MblMwCartesianFloat = entry.valueAs()
                print("\(pt.x) \(pt.y) \(pt.z)")
            }
            
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 30)
    }
    
    func testGyroBMI270Data() throws {
        let device = try XCTUnwrap(device)
        device.apiAccessQueue.async { [self] in
            let expectation = XCTestExpectation(description: "get gyro data")
            // Set the max range of the accelerometer
            mbl_mw_gyro_bmi270_set_range(device.board, MBL_MW_GYRO_BOSCH_RANGE_2000dps)
            mbl_mw_gyro_bmi270_set_odr(device.board, MBL_MW_GYRO_BOSCH_ODR_50Hz)
            mbl_mw_gyro_bmi270_write_config(device.board)
            // Get acc signal
            let gyroSignal = mbl_mw_gyro_bmi270_get_rotation_data_signal(device.board)
            mbl_mw_datasignal_subscribe(gyroSignal, bridge(obj: self)) { (context, dataPtr) in
                let this: GyroscopeTests = bridge(ptr: context!)
                let df = DateFormatter()
                df.dateFormat = "y-MM-dd H:m:ss.SSSS"
                let date = df.string(from: dataPtr!.pointee.timestamp) // -> "2016-11-17 17:51:15.1720"
                print(dataPtr!.pointee.epoch, date, dataPtr!.pointee.valueAs() as MblMwCartesianFloat)
                this.data.append(dataPtr!.pointee.copy())
            }
            // Start sampling and start acc
            mbl_mw_gyro_bmi270_enable_rotation_sampling(device.board)
            mbl_mw_gyro_bmi270_start(device.board)
            // Stop after 5 seconds
            device.apiAccessQueue.asyncAfter(deadline: .now() + 5) {
                // Stop the stream
                mbl_mw_gyro_bmi270_stop(device.board)
                mbl_mw_gyro_bmi270_disable_rotation_sampling(device.board)
                mbl_mw_datasignal_unsubscribe(gyroSignal)
                for entry in self.data {
                    let pt: MblMwCartesianFloat = entry.valueAs()
                    print("\(pt.x) \(pt.y) \(pt.z)")
                }

                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testGyroBMI160PackedData() throws {
        let device = try XCTUnwrap(device)
        let expectation = XCTestExpectation(description: "get gyro packed data")
        // Set the max range of the accelerometer
        mbl_mw_gyro_bmi160_set_range(device.board, MetaWearCpp.MBL_MW_GYRO_BOSCH_RANGE_2000dps)
        mbl_mw_gyro_bmi160_set_odr(device.board, MetaWearCpp.MBL_MW_GYRO_BOSCH_ODR_100Hz)
        mbl_mw_gyro_bmi160_write_config(device.board)
        // Get acc signal
        let gyroSignal = mbl_mw_gyro_bmi160_get_packed_rotation_data_signal(device.board)
        mbl_mw_datasignal_subscribe(gyroSignal, bridge(obj: self)) { (context, dataPtr) in
            let this: GyroscopeTests = bridge(ptr: context!)
            let df = DateFormatter()
            df.dateFormat = "y-MM-dd H:m:ss.SSSS"
            let date = df.string(from: dataPtr!.pointee.timestamp) // -> "2016-11-17 17:51:15.1720"
            print(dataPtr!.pointee.epoch, date, dataPtr!.pointee.valueAs() as MblMwCartesianFloat)
            this.data.append(dataPtr!.pointee.copy())
        }
        // Start sampling and start acc
        mbl_mw_gyro_bmi160_enable_rotation_sampling(device.board)
        mbl_mw_gyro_bmi160_start(device.board)
        // Stop after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            // Stop the stream
            mbl_mw_gyro_bmi160_stop(device.board)
            mbl_mw_gyro_bmi160_disable_rotation_sampling(device.board)
            mbl_mw_datasignal_unsubscribe(gyroSignal)
            for entry in self.data {
                let pt: MblMwCartesianFloat = entry.valueAs()
                print("\(pt.x) \(pt.y) \(pt.z)")
            }
            
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 30)
    }
    
    func testGyroBMI270PackedData() throws {
        let device = try XCTUnwrap(device)
        let expectation = XCTestExpectation(description: "get gyro packed data")
        // Set the max range of the accelerometer
        mbl_mw_gyro_bmi270_set_range(device.board, MetaWearCpp.MBL_MW_GYRO_BOSCH_RANGE_2000dps)
        mbl_mw_gyro_bmi270_set_odr(device.board, MetaWearCpp.MBL_MW_GYRO_BOSCH_ODR_100Hz)
        mbl_mw_gyro_bmi270_write_config(device.board)
        // Get acc signal
        let gyroSignal = mbl_mw_gyro_bmi270_get_packed_rotation_data_signal(device.board)
        mbl_mw_datasignal_subscribe(gyroSignal, bridge(obj: self)) { (context, dataPtr) in
            let this: GyroscopeTests = bridge(ptr: context!)
            let df = DateFormatter()
            df.dateFormat = "y-MM-dd H:m:ss.SSSS"
            let date = df.string(from: dataPtr!.pointee.timestamp) // -> "2016-11-17 17:51:15.1720"
            print(dataPtr!.pointee.epoch, date, dataPtr!.pointee.valueAs() as MblMwCartesianFloat)
            this.data.append(dataPtr!.pointee.copy())
        }
        // Start sampling and start acc
        mbl_mw_gyro_bmi270_enable_rotation_sampling(device.board)
        mbl_mw_gyro_bmi270_start(device.board)
        // Stop after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            // Stop the stream
            mbl_mw_gyro_bmi270_stop(device.board)
            mbl_mw_gyro_bmi270_disable_rotation_sampling(device.board)
            mbl_mw_datasignal_unsubscribe(gyroSignal)
            for entry in self.data {
                let pt: MblMwCartesianFloat = entry.valueAs()
                print("\(pt.x) \(pt.y) \(pt.z)")
            }
            
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 30)
    }
    
}
