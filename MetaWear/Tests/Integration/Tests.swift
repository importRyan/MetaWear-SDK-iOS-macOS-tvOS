//
//  Tests.swift
//  MetaWear
//
//  Created by Laura Kassovic on 3/18/21.
//  Copyright © 2021 Stephen Schiffli. All rights reserved.
//

import XCTest
import Combine
@testable import MetaWear
@testable import MetaWearCpp

class Tests: XCTestCase, MetaWearTestCase {

    var device: MetaWear?
    var data: [MetaWearData] = []
    var expectation: XCTestExpectation?
    var counter: Int = 0
    var handlers = MblMwLogDownloadHandler()
    var fuser: OpaquePointer!

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
    
    func testONLED() throws {
        try wait(forVisualInspection: 5) { device, exp in
            var pattern = MblMwLedPattern()
            mbl_mw_led_load_preset_pattern(&pattern, MBL_MW_LED_PRESET_BLINK)
            mbl_mw_led_write_pattern(device.board, &pattern, MBL_MW_LED_COLOR_GREEN)
            mbl_mw_led_play(device.board)
        }
    }
    
    func testOFFLED() throws {
        try wait(forVisualInspection: 5) { device, exp in
            mbl_mw_led_stop_and_clear(device.board)
        }
    }
    
    func testSetDeviceName() throws {
        try wait(forVisualInspection: 2) { device, exp in
            let name = "TEMPY"
            mbl_mw_settings_set_device_name(device.board, name, UInt8(name.count))
        }
    }
    
    func testSetDeviceNamePermanently() throws {
        try wait(timeout: 4) { device, exp, _ in
            let name = "TEMPY"
            mbl_mw_macro_record(device.board, 1)
            mbl_mw_settings_set_device_name(device.board, name, UInt8(name.count))
            mbl_mw_macro_end_record(device.board, bridgeRetained(obj: exp)) { (context, board, value) in
                print("macro done")
                let exp: XCTestExpectation = bridgeTransfer(ptr: context!)
                exp.fulfill()
            }
        }
    }
    
    func testLinkSaturation() throws {
        let device = try XCTUnwrap(device)
        expectation = XCTestExpectation(description: "wait to get all")
        // Set the max range of the accelerometer
        let signal = mbl_mw_debug_get_key_register_data_signal(device.board)
        mbl_mw_datasignal_subscribe(signal,  bridgeRetained(obj: self)) { (context, dataPtr) in
            let this: Tests = bridge(ptr: context!)
            let val: UInt32 = dataPtr!.pointee.valueAs()
            XCTAssertEqual(this.counter, Int(val))
            if (this.counter == 1000) {
                this.expectation?.fulfill()
            }
            this.counter += 1
        }
        device.apiAccessQueue.async {
            self.counter = 1
            for i in 1...1000 {
                mbl_mw_debug_set_key_register(device.board, UInt32(i))
                mbl_mw_datasignal_read(signal)
            }
        }
        wait(for: [expectation!], timeout: 30)
    }
    
    func testRSSI() throws {
        try wait(timeout: 30) { device, exp, subs in
            device.rssiPublisher
                .sink { signal in
                    XCTAssertGreaterThan(signal, -80)
                    XCTAssertLessThan(signal, 0)
                    exp.fulfill()
                }
                .store(in: &subs)
        }
    }
    
    func testBMI160Fuser() throws {
        let device = try XCTUnwrap(device)
        expectation = XCTestExpectation(description: "get accel logger")
        mbl_mw_acc_set_odr(device.board, 25)
        mbl_mw_acc_write_acceleration_config(device.board)
        let accSignal = mbl_mw_acc_bosch_get_acceleration_data_signal(device.board)!
        mbl_mw_gyro_bmi160_set_odr(device.board, MBL_MW_GYRO_BOSCH_ODR_25Hz)
        mbl_mw_gyro_bmi160_write_config(device.board)
        let gyroSignal = mbl_mw_gyro_bmi160_get_rotation_data_signal(device.board)!

        var subs = Set<AnyCancellable>()
        accSignal
            .fuserCreate(with: gyroSignal)
            .logger()
            .sink { FailOnError($0) } receiveValue: { logger in
                self.fuser = logger
                print("Started logger: ", logger)
            }
            .store(in: &subs)

        mbl_mw_acc_enable_acceleration_sampling(device.board)
        mbl_mw_acc_start(device.board)
        mbl_mw_gyro_bmi160_enable_rotation_sampling(device.board)
        mbl_mw_gyro_bmi160_start(device.board)
        mbl_mw_logging_start(device.board, 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            mbl_mw_acc_stop(device.board)
            mbl_mw_acc_disable_acceleration_sampling(device.board)
            mbl_mw_gyro_bmi160_stop(device.board)
            mbl_mw_gyro_bmi160_disable_rotation_sampling(device.board)
            mbl_mw_logging_stop(device.board)
            mbl_mw_logging_flush_page(device.board)
            let fuserLogger = self.fuser
            mbl_mw_logger_subscribe(fuserLogger, bridge(obj: self), { (context, obj) in
                print(obj!.pointee.epoch, obj!.pointee)
            })
            self.handlers.context = bridge(obj: self)
            self.handlers.received_progress_update = { (context, remainingEntries, totalEntries) in
                let this: Tests = bridge(ptr: context!)
                if remainingEntries == 0 {
                    this.expectation?.fulfill()
                }
            }
            self.handlers.received_unknown_entry = { (context, id, epoch, data, length) in
                print("received_unknown_entry")
            }
            self.handlers.received_unhandled_entry = { (context, data) in
                print("received_unhandled_entry")
            }
            mbl_mw_logging_download(device.board, 0, &self.handlers)
        }
        wait(for: [expectation!], timeout: 60)
    }
    
    func testBMI270Fuser() throws {
        let device = try XCTUnwrap(device)
        expectation = XCTestExpectation(description: "get accel logger")

        mbl_mw_acc_set_odr(device.board, 25)
        mbl_mw_acc_write_acceleration_config(device.board)
        let accSignal = mbl_mw_acc_bosch_get_acceleration_data_signal(device.board)!
        mbl_mw_gyro_bmi270_set_odr(device.board, MBL_MW_GYRO_BOSCH_ODR_25Hz)
        mbl_mw_gyro_bmi270_write_config(device.board)
        let gyroSignal = mbl_mw_gyro_bmi270_get_rotation_data_signal(device.board)!

        var subs = Set<AnyCancellable>()
        accSignal
            .fuserCreate(with: gyroSignal)
            .logger()
            .sink { FailOnError($0) } receiveValue: { logger in
                self.fuser = logger
                print("Started logger: ", logger)
            }
            .store(in: &subs)

        mbl_mw_acc_enable_acceleration_sampling(device.board)
        mbl_mw_acc_start(device.board)
        mbl_mw_gyro_bmi270_enable_rotation_sampling(device.board)
        mbl_mw_gyro_bmi270_start(device.board)
        mbl_mw_logging_start(device.board, 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            mbl_mw_acc_stop(device.board)
            mbl_mw_acc_disable_acceleration_sampling(device.board)
            mbl_mw_gyro_bmi270_stop(device.board)
            mbl_mw_gyro_bmi270_disable_rotation_sampling(device.board)
            mbl_mw_logging_stop(device.board)
            mbl_mw_logging_flush_page(device.board)
            let fuserLogger = self.fuser
            mbl_mw_logger_subscribe(fuserLogger, bridge(obj: self), { (context, obj) in
                print(obj!.pointee.epoch, obj!.pointee)
            })
            self.handlers.context = bridge(obj: self)
            self.handlers.received_progress_update = { (context, remainingEntries, totalEntries) in
                let this: Tests = bridge(ptr: context!)
                if remainingEntries == 0 {
                    this.expectation?.fulfill()
                }
            }
            self.handlers.received_unknown_entry = { (context, id, epoch, data, length) in
                print("received_unknown_entry")
            }
            self.handlers.received_unhandled_entry = { (context, data) in
                print("received_unhandled_entry")
            }
            mbl_mw_logging_download(device.board, 0, &self.handlers)
        }
        wait(for: [expectation!], timeout: 60)
    }

    func testLogSensorFusion() throws {
        let device = try XCTUnwrap(device)
        expectation = XCTestExpectation(description: "expectation")
        let accelRange = MBL_MW_SENSOR_FUSION_ACC_RANGE_16G
        let gyroRange = MBL_MW_SENSOR_FUSION_GYRO_RANGE_2000DPS
        let sensorFusionMode = MBL_MW_SENSOR_FUSION_MODE_IMU_PLUS
        mbl_mw_sensor_fusion_set_acc_range(device.board, accelRange)
        mbl_mw_sensor_fusion_set_gyro_range(device.board, gyroRange)
        mbl_mw_sensor_fusion_set_mode(device.board, sensorFusionMode)
        let eulerSignal = mbl_mw_sensor_fusion_get_data_signal(device.board, MBL_MW_SENSOR_FUSION_DATA_EULER_ANGLE)!

        var subs = Set<AnyCancellable>()
        eulerSignal
            .logger()
            .sink { FailOnError($0) } receiveValue: { logger in
                self.fuser = logger
                print("Started logger: ", logger)
            }
            .store(in: &subs)

        mbl_mw_logging_start(device.board, 0)
        mbl_mw_sensor_fusion_clear_enabled_mask(device.board)
        mbl_mw_sensor_fusion_enable_data(device.board, MBL_MW_SENSOR_FUSION_DATA_EULER_ANGLE)
        mbl_mw_sensor_fusion_write_config(device.board)
        mbl_mw_sensor_fusion_start(device.board)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            mbl_mw_sensor_fusion_stop(device.board)
            mbl_mw_sensor_fusion_clear_enabled_mask(device.board)
            let fusionLogger = self.fuser
            mbl_mw_logger_subscribe(fusionLogger, bridge(obj: self), { (context, dataPtr) in
                let timestamp = dataPtr!.pointee.timestamp
                let euler: MblMwEulerAngles = dataPtr!.pointee.valueAs()
                print("euler : \(timestamp) \(euler)")
            })
            self.handlers.context = bridge(obj: self)
            self.handlers.received_progress_update = { (context, remainingEntries, totalEntries) in
                if remainingEntries == 0 {
                    print("done \(Date())")
                    let this: Tests = bridge(ptr: context!)
                    this.expectation?.fulfill()
                }
            }
            self.handlers.received_unknown_entry = { (context, id, epoch, data, length) in
                print("received_unknown_entry")
            }
            self.handlers.received_unhandled_entry = { (context, data) in
                print("received_unhandled_entry")
            }
            mbl_mw_logging_download(device.board, 0, &self.handlers)
            print("stopping \(Date())")
        }
        wait(for: [expectation!], timeout: 300)
    }
    
    func testEuler() throws {
        let device = try XCTUnwrap(device)
        expectation = XCTestExpectation(description: "expectation")
        let accelRange = MBL_MW_SENSOR_FUSION_ACC_RANGE_16G
        let gyroRange = MBL_MW_SENSOR_FUSION_GYRO_RANGE_2000DPS
        let sensorFusionMode = MBL_MW_SENSOR_FUSION_MODE_IMU_PLUS
        mbl_mw_sensor_fusion_set_acc_range(device.board, accelRange)
        mbl_mw_sensor_fusion_set_gyro_range(device.board, gyroRange)
        mbl_mw_sensor_fusion_set_mode(device.board, sensorFusionMode)
        let eulerSignal = mbl_mw_sensor_fusion_get_data_signal(device.board, MBL_MW_SENSOR_FUSION_DATA_EULER_ANGLE)!
        mbl_mw_datasignal_subscribe(eulerSignal, bridge(obj: self)) { (context, dataPtr) in
            let this: Tests = bridge(ptr: context!)
            print(dataPtr!.pointee.valueAs() as MblMwEulerAngles)
            this.data.append(dataPtr!.pointee.copy())
        }
        mbl_mw_sensor_fusion_clear_enabled_mask(device.board)
        mbl_mw_sensor_fusion_enable_data(device.board, MBL_MW_SENSOR_FUSION_DATA_EULER_ANGLE)
        mbl_mw_sensor_fusion_write_config(device.board)
        mbl_mw_sensor_fusion_start(device.board)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            mbl_mw_sensor_fusion_stop(device.board)
            mbl_mw_sensor_fusion_clear_enabled_mask(device.board)
            for entry in self.data {
                let pt: MblMwEulerAngles = entry.valueAs()
                print("\(pt)")
            }
            self.expectation?.fulfill()
        }
        wait(for: [expectation!], timeout: 300)
    }
    
    func testReadMacro() throws {
        let expectedMessages = [ // 0f82000119?
            "Received: 0f82",
            "Received: 0f82",
            "Received: 0f82",
            "Received: 0f82",
            "Received: 0f82",
            "Received: 0f82",
            "Received: 0f82"
        ]

        var receivedMessages = [String]()

        try wait(timeout: 30) { device, exp, _ in
            for i: UInt8 in 0..<8 {
                let cmd: [UInt8] = [0x0F, 0x82, i]
                mbl_mw_debug_send_command(device.board, cmd, UInt8(cmd.count))
            }

            ConsoleLogger.shared.didLog = { string in
                guard string.hasPrefix("Received: ") else { return }
                receivedMessages.append(string)
                if receivedMessages.suffix(expectedMessages.endIndex) == expectedMessages {
                    exp.fulfill()
                }
            }
        }
    }
    
}


