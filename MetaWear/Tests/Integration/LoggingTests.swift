//
//  LoggingTests.swift
//  MetaWear
//
//  Created by Laura Kassovic on 3/9/21.
//  Copyright © 2021 Stephen Schiffli. All rights reserved.
//

import Foundation
import XCTest
import Combine
@testable import MetaWear
@testable import MetaWearCpp

class LoggingTests: XCTestCase, MetaWearTestCase {
    var device: MetaWear?
    var data: [MWData] = []
    var expectation: XCTestExpectation?
    var counter: Int = 0
    var handlers = MblMwLogDownloadHandler()
    var rawHandlers = MblMwRawLogDownloadHandler()
    var logger: OpaquePointer?
    var loggers: [String: OpaquePointer] = [:]
    var loggerID: UInt8 = 0

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
    
    func testAccelLogging() throws {
        let device = try XCTUnwrap(device)
        expectation = XCTestExpectation(description: "get accel logger")

        device.apiAccessQueue.async { [self] in
            let signal = mbl_mw_acc_bosch_get_acceleration_data_signal(device.board)!
            mbl_mw_datasignal_log(signal, bridge(obj: self)) { (context, logger) in
                let this: LoggingTests = bridge(ptr: context!)
                let cString = mbl_mw_logger_generate_identifier(logger)!
                let identifier = String(cString: cString)
                print("Generated Identifier for logger: ", identifier)
                let cId = mbl_mw_logger_get_id(logger)
                this.loggerID = cId
                print("Generated ID for logger: ", cId)
                this.logger = logger!
                print("Started logger: ", this.logger as Any)
            }
            mbl_mw_logging_start(device.board, 0)
            mbl_mw_acc_enable_acceleration_sampling(device.board)
            mbl_mw_acc_start(device.board)
        }

        device.apiAccessQueue.asyncAfter(deadline: .now() + 20) {
            mbl_mw_acc_stop(device.board)
            mbl_mw_acc_disable_acceleration_sampling(device.board)
            mbl_mw_logging_stop(device.board)
            mbl_mw_logging_flush_page(device.board)
            let myLogger = mbl_mw_logger_lookup_id(device.board,self.loggerID)
            mbl_mw_logger_subscribe(myLogger, bridge(obj: self), { (context, obj) in
                let acceleration: MblMwCartesianFloat = obj!.pointee.valueAs()
                print(obj!.pointee.epoch, acceleration)
            })
            self.handlers.context = bridge(obj: self)
            self.handlers.received_progress_update = { (context, remainingEntries, totalEntries) in
                let this: LoggingTests = bridge(ptr: context!)
                if remainingEntries == 0 {
                    print("done with logger: ", this.logger  as Any)
                    mbl_mw_logger_remove(this.logger)
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

        wait(for: [expectation!], timeout: 120)
    }
    
    func testGyroBMI160Logging() throws {
        let device = try XCTUnwrap(device)
        expectation = XCTestExpectation(description: "get accel logger")
        let gyroSignal = mbl_mw_gyro_bmi160_get_rotation_data_signal(device.board)!
        mbl_mw_datasignal_log(gyroSignal, bridge(obj: self)) { (context, logger) in
            let this: LoggingTests = bridge(ptr: context!)
            let cString = mbl_mw_logger_generate_identifier(logger)!
            let identifier = String(cString: cString)
            print("Generated Identifier for logger: ", identifier)
            let cId = mbl_mw_logger_get_id(logger)
            this.loggerID = cId
            print("Generated ID for logger: ", cId)
            this.logger = logger!
            print("Started logger: ", this.logger  as Any)
        }
        mbl_mw_gyro_bmi160_enable_rotation_sampling(device.board)
        mbl_mw_gyro_bmi160_start(device.board)
        mbl_mw_logging_start(device.board, 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            mbl_mw_gyro_bmi160_stop(device.board)
            mbl_mw_gyro_bmi160_disable_rotation_sampling(device.board)
            mbl_mw_logging_stop(device.board)
            mbl_mw_logging_flush_page(device.board)
            let myLogger = mbl_mw_logger_lookup_id(device.board,self.loggerID)
            mbl_mw_logger_subscribe(myLogger, bridge(obj: self), { (context, obj) in
                let rotation: MblMwCartesianFloat = obj!.pointee.valueAs()
                print(obj!.pointee.epoch, rotation)
            })
            self.handlers.context = bridge(obj: self)
            self.handlers.received_progress_update = { (context, remainingEntries, totalEntries) in
                let this: LoggingTests = bridge(ptr: context!)
                if remainingEntries == 0 {
                    print("done with logger: ", this.logger as Any)
                    mbl_mw_logger_remove(this.logger)
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
    
    func testAccelGyroBMI160Logging() throws {
        let device = try XCTUnwrap(device)
        expectation = XCTestExpectation(description: "get accel logger")
        mbl_mw_acc_set_odr(device.board, 25)
        mbl_mw_acc_write_acceleration_config(device.board)
        let accSignal = mbl_mw_acc_bosch_get_acceleration_data_signal(device.board)!
        mbl_mw_datasignal_log(accSignal, bridge(obj: self)) { (context, logger) in
            let this: LoggingTests = bridge(ptr: context!)
            let cString = mbl_mw_logger_generate_identifier(logger)!
            let identifier = String(cString: cString)
            this.loggers[identifier] = logger!
            print("Generated Identifier for logger: ", identifier)
            let cId = mbl_mw_logger_get_id(logger)
            this.loggerID = cId
            print("Generated ID for logger: ", cId)
            this.loggers["acceleration"] = logger!
            print("Started logger: ", this.loggers["acceleration"] as Any)
        }
        mbl_mw_gyro_bmi160_set_odr(device.board, MBL_MW_GYRO_BOSCH_ODR_25Hz)
        mbl_mw_gyro_bmi160_write_config(device.board)
        let gyroSignal = mbl_mw_gyro_bmi160_get_rotation_data_signal(device.board)!
        mbl_mw_datasignal_log(gyroSignal, bridge(obj: self)) { (context, logger) in
            let this: LoggingTests = bridge(ptr: context!)
            let cString = mbl_mw_logger_generate_identifier(logger)!
            let identifier = String(cString: cString)
            print("Generated Identifier for logger: ", identifier)
            let cId = mbl_mw_logger_get_id(logger)
            this.loggerID = cId
            print("Generated ID for logger: ", cId)
            this.loggers["angular-velocity"] = logger!
            print("Started logger: ", this.loggers["angular-velocity"] as Any)
        }
        mbl_mw_acc_enable_acceleration_sampling(device.board)
        mbl_mw_acc_start(device.board)
        mbl_mw_gyro_bmi160_enable_rotation_sampling(device.board)
        mbl_mw_gyro_bmi160_start(device.board)
        mbl_mw_logging_start(device.board, 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            mbl_mw_acc_stop(device.board)
            mbl_mw_acc_disable_acceleration_sampling(device.board)
            mbl_mw_gyro_bmi160_stop(device.board)
            mbl_mw_gyro_bmi160_disable_rotation_sampling(device.board)
            mbl_mw_logging_stop(device.board)
            mbl_mw_logging_flush_page(device.board)
            let accLogger = self.loggers["acceleration"]
            mbl_mw_logger_subscribe(accLogger, bridge(obj: self), { (context, obj) in
                let acceleration: MblMwCartesianFloat = obj!.pointee.valueAs()
                print(obj!.pointee.epoch, acceleration)
            })
            let gyroLogger = self.loggers["angular-velocity"]
            mbl_mw_logger_subscribe(gyroLogger, bridge(obj: self), { (context, obj) in
                let rotation: MblMwCartesianFloat = obj!.pointee.valueAs()
                print(obj!.pointee.epoch, rotation)
            })
            self.handlers.context = bridge(obj: self)
            self.handlers.received_progress_update = { (context, remainingEntries, totalEntries) in
                let this: LoggingTests = bridge(ptr: context!)
                if remainingEntries == 0 {
                    print("done with logger: ", this.loggers["acceleration"] as Any)
                    mbl_mw_logger_remove(this.loggers["acceleration"])
                    print("done with logger: ", this.loggers["angular-velocity"] as Any)
                    mbl_mw_logger_remove(this.loggers["angular-velocity"])
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
    
    func testAccelGyroBMI270Logging() throws {
        let device = try XCTUnwrap(device)
        expectation = XCTestExpectation(description: "get accel logger")
        mbl_mw_acc_set_odr(device.board, 25)
        mbl_mw_acc_write_acceleration_config(device.board)
        let accSignal = mbl_mw_acc_bosch_get_acceleration_data_signal(device.board)!
        mbl_mw_datasignal_log(accSignal, bridge(obj: self)) { (context, logger) in
            let this: LoggingTests = bridge(ptr: context!)
            let cString = mbl_mw_logger_generate_identifier(logger)!
            let identifier = String(cString: cString)
            this.loggers[identifier] = logger!
            print("Generated Identifier for logger: ", identifier)
            let cId = mbl_mw_logger_get_id(logger)
            this.loggerID = cId
            print("Generated ID for logger: ", cId)
            this.loggers["acceleration"] = logger!
            print("Started logger: ", this.loggers["acceleration"] as Any)
        }
        mbl_mw_gyro_bmi270_set_odr(device.board, MBL_MW_GYRO_BOSCH_ODR_25Hz)
        mbl_mw_gyro_bmi270_write_config(device.board)
        let gyroSignal = mbl_mw_gyro_bmi270_get_rotation_data_signal(device.board)!
        mbl_mw_datasignal_log(gyroSignal, bridge(obj: self)) { (context, logger) in
            let this: LoggingTests = bridge(ptr: context!)
            let cString = mbl_mw_logger_generate_identifier(logger)!
            let identifier = String(cString: cString)
            print("Generated Identifier for logger: ", identifier)
            let cId = mbl_mw_logger_get_id(logger)
            this.loggerID = cId
            print("Generated ID for logger: ", cId)
            this.loggers["angular-velocity"] = logger!
            print("Started logger: ", this.loggers["angular-velocity"] as Any)
        }
        mbl_mw_acc_enable_acceleration_sampling(device.board)
        mbl_mw_acc_start(device.board)
        mbl_mw_gyro_bmi270_enable_rotation_sampling(device.board)
        mbl_mw_gyro_bmi270_start(device.board)
        mbl_mw_logging_start(device.board, 0)


        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            mbl_mw_acc_stop(device.board)
            mbl_mw_acc_disable_acceleration_sampling(device.board)
            mbl_mw_gyro_bmi270_stop(device.board)
            mbl_mw_gyro_bmi270_disable_rotation_sampling(device.board)
            mbl_mw_logging_stop(device.board)
            mbl_mw_logging_flush_page(device.board)
            let accLogger = self.loggers["acceleration"]
            mbl_mw_logger_subscribe(accLogger, bridge(obj: self), { (context, obj) in
                let acceleration: MblMwCartesianFloat = obj!.pointee.valueAs()
                print(obj!.pointee.epoch, acceleration)
            })
            let gyroLogger = self.loggers["angular-velocity"]
            mbl_mw_logger_subscribe(gyroLogger, bridge(obj: self), { (context, obj) in
                let rotation: MblMwCartesianFloat = obj!.pointee.valueAs()
                print(obj!.pointee.epoch, rotation)
            })
            self.handlers.context = bridge(obj: self)
            self.handlers.received_progress_update = { (context, remainingEntries, totalEntries) in
                let this: LoggingTests = bridge(ptr: context!)
                if remainingEntries == 0 {
                    print("done with logger: ", this.loggers["acceleration"] as Any)
                    mbl_mw_logger_remove(this.loggers["acceleration"])
                    print("done with logger: ", this.loggers["angular-velocity"] as Any)
                    mbl_mw_logger_remove(this.loggers["angular-velocity"])
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
    
    func testAccelRawLogging() throws {
        let device = try XCTUnwrap(device)
        expectation = XCTestExpectation(description: "get accel raw logger")
        let signal = mbl_mw_acc_bosch_get_acceleration_data_signal(device.board)!
        mbl_mw_datasignal_log(signal, bridge(obj: self)) { (context, logger) in
            let this: LoggingTests = bridge(ptr: context!)
            let cString = mbl_mw_logger_generate_identifier(logger)!
            let identifier = String(cString: cString)
            print("Generated Identifier for logger: ", identifier)
            let cId = mbl_mw_logger_get_id(logger)
            this.loggerID = cId
            print("Generated ID for logger: ", cId)
            this.logger = logger!
        }
        mbl_mw_logging_start(device.board, 0)
        mbl_mw_acc_enable_acceleration_sampling(device.board)
        mbl_mw_acc_start(device.board)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            mbl_mw_acc_stop(device.board)
            mbl_mw_acc_disable_acceleration_sampling(device.board)
            mbl_mw_logging_stop(device.board)
            mbl_mw_logging_flush_page(device.board)
            let myLogger = mbl_mw_logger_lookup_id(device.board,self.loggerID)
            mbl_mw_logger_subscribe(myLogger, bridge(obj: self), { (context, obj) in
                let acceleration: MblMwCartesianFloat = obj!.pointee.valueAs()
                print(obj!.pointee.epoch, acceleration)//Double(acceleration.x), y: Double(acceleration.y), z: Double(acceleration.z)
            })
            self.rawHandlers.context = bridge(obj: self)
            self.rawHandlers.received_entry = { (context, id, uid, tick, data) in
                print("ID: ",id, "UID: ", uid, "TICK: ", tick, "DATA :", data)
            }
            mbl_mw_logging_raw_download(device.board, 0, &self.rawHandlers)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 17) {
            print("done with logger: ", self.logger as Any)
            mbl_mw_logger_remove(self.logger)
            self.expectation?.fulfill()
        }
        wait(for: [expectation!], timeout: 40)
    }
    
}
