/**
 * ManualTests.swift
 * MetaWear-Tests
 *
 * Created by Stephen Schiffli on 12/28/17.
 * Copyright 2017 MbientLab Inc. All rights reserved.
 *
 * IMPORTANT: Your use of this Software is limited to those specific rights
 * granted under the terms of a software license agreement between the user who
 * downloaded the software, his/her employer (which must be your employer) and
 * MbientLab Inc, (the "License").  You may not use this Software unless you
 * agree to abide by the terms of the License which can be found at
 * www.mbientlab.com/terms.  The License limits your use, and you acknowledge,
 * that the Software may be modified, copied, and distributed when used in
 * conjunction with an MbientLab Inc, product.  Other than for the foregoing
 * purpose, you may not use, reproduce, copy, prepare derivative works of,
 * modify, distribute, perform, display or sell this Software and/or its
 * documentation for any purpose.
 *
 * YOU FURTHER ACKNOWLEDGE AND AGREE THAT THE SOFTWARE AND DOCUMENTATION ARE
 * PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTY OF MERCHANTABILITY, TITLE,
 * NON-INFRINGEMENT AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL
 * MBIENTLAB OR ITS LICENSORS BE LIABLE OR OBLIGATED UNDER CONTRACT, NEGLIGENCE,
 * STRICT LIABILITY, CONTRIBUTION, BREACH OF WARRANTY, OR OTHER LEGAL EQUITABLE
 * THEORY ANY DIRECT OR INDIRECT DAMAGES OR EXPENSES INCLUDING BUT NOT LIMITED
 * TO ANY INCIDENTAL, SPECIAL, INDIRECT, PUNITIVE OR CONSEQUENTIAL DAMAGES, LOST
 * PROFITS OR LOST DATA, COST OF PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY,
 * SERVICES, OR ANY CLAIMS BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY
 * DEFENSE THEREOF), OR OTHER SIMILAR COSTS.
 *
 * Should you have any questions regarding your right to use this Software,
 * contact MbientLab via email: hello@mbientlab.com
 */

import XCTest
@testable import MetaWear
@testable import MetaWearCpp
import Combine
import CoreBluetooth

class ManualTests: XCTestCase, MetaWearTestCase {

    var device: MetaWear?
    var counter: OpaquePointer!
    var comparator: OpaquePointer!
    var id: Int!

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

#warning("There were no assertions in the test.")
    func testJumpToBootloader() throws {
        let device = try XCTUnwrap(device)
        mbl_mw_debug_jump_to_bootloader(device.board)
    }

    func testUserMacro() throws {
        try wait(forVisualInspection: 60) { device, exp in
            exp.isInverted = false

            print("macro")
            mbl_mw_macro_record(device.board, 1)
            let switcher = mbl_mw_switch_get_state_data_signal(device.board)
            print("switch: ", switcher as Any)

            var subs = Set<AnyCancellable>()
            try XCTUnwrap(switcher)
                .accounterCreateCount()
                .flatMap { counter -> AnyPublisher<OpaquePointer,MetaWearError> in
                    self.counter = counter
                    print("counter: ", counter)

                    return counter.comparatorCreate(
                        op: MBL_MW_COMPARATOR_OP_EQ,
                        mode: MBL_MW_COMPARATOR_MODE_ABSOLUTE,
                        references: [Float(2999)]
                    )
                }
                .flatMap { comparator -> AnyPublisher<Void,MetaWearError> in
                    print("comp: ", comparator)
                    mbl_mw_event_record_commands(comparator)
                    print("led")
                    device.ledStartFlashing(color: .red, intensity: 1.0, repeating: 1)
                    mbl_mw_dataprocessor_counter_set_state(self.counter, 0)
                    print("event end")
                    return comparator.eventEndRecording().eraseToAnyPublisher()
                }
                .flatMap { _ -> AnyPublisher<Int32,MetaWearError> in
                    print("macro end")
                    return device.publish().macroEndRecording()
                        .handleEvents(receiveOutput: { macroID in
                            let _id = Int(macroID)
                            self.id = _id
                            print("macro with id: ", _id)
                            print("macro execute")
                            mbl_mw_macro_execute(device.board, UInt8(macroID))
                        })
                        .eraseToAnyPublisher()
                }
                .sink(receiveCompletion: { completion in
                    guard case let .failure(error) = completion else { return }
                    XCTFail(error.localizedDescription)

                }, receiveValue: { _ in
                    print("done")
                    exp.fulfill()
                })
                .store(in: &subs)

        }
    }

    func testFlashLED() throws {
        try wait(forVisualInspection: 4) { device, _ in
            device.ledStartFlashing(color: .green, intensity: 1.0, repeating: 10)
        }
    }

#warning("iBeacon part was commented out")
    func testiBeacon() throws {
        try wait(forVisualInspection: 4) { device, _ in
            device.ledStartFlashing(color: .green, intensity: 1.0, repeating: 2)
            //mbl_mw_ibeacon_enable(device.board)
            //mbl_mw_ibeacon_set_major(device.board, 1111)
            //mbl_mw_ibeacon_set_minor(device.board, 2222)
            //        mbl_mw_debug_disconnect(device.board)
        }
    }

    // 020101
    
    func testWhitelist() throws {
        try wait(forVisualInspection: 60) { device, _ in
            device.ledStartFlashing(color: .green, intensity: 1.0, repeating: 2)
            var address = MblMwBtleAddress(address_type: 0, address: (0x70, 0x9e, 0x38, 0x95, 0x01, 0x00))
            mbl_mw_settings_add_whitelist_address(device.board, 0, &address)
            mbl_mw_settings_set_ad_parameters(device.board, 418, 0, MBL_MW_BLE_AD_TYPE_CONNECTED_DIRECTED)
            // mbl_mw_settings_set_whitelist_filter_mode(device.board, MBL_MW_WHITELIST_FILTER_SCAN_AND_CONNECTION_REQUESTS)
            mbl_mw_debug_disconnect(device.board)
        }
    }
    
    func testClearMacro() throws {
        try wait(forVisualInspection: 60) { device, _ in
            mbl_mw_macro_erase_all(device.board)
            mbl_mw_debug_reset_after_gc(device.board)
            mbl_mw_debug_disconnect(device.board)

        }
    }
}
