/**
 * Manual+ConnectDisconnectTests.swift
 * MetaWear-Tests
 *
 * Created by Ryan Ferrell.
 * Copyright 2021 MbientLab Inc. All rights reserved.
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

class ManualConnectDisconnectTests: XCTestCase, MetaWearTestCase {

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

    func testCancelPendingConnection_Connect_CancelAsyncAfter() throws {
        let exp = XCTestExpectation(description: "Disconnects while connecting")

        // Subscribe to state changes before acting.
        var subs = Set<AnyCancellable>()
        var step = 0
        device?.connectionState
            .sink(receiveValue: { state in
                step += 1

                if state == .connected, step == 1 {
                    self.device?.disconnect()
                }

                if state == .disconnected, step == 3 {
                    self.device?.connect()

                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.05) {
                        self.device?.disconnect()
                    }
                }

                if state == .disconnected, step > 5 {
                    exp.fulfill()
                }
            })
            .store(in: &subs)

        wait(for: [exp], timeout: 60)
    }

    func testCancelPendingConnection_Connect_CancelDuringConnection() throws {
        let exp = XCTestExpectation(description: "Disconnects while connecting")

        // Subscribe to state changes before acting.
        var subs = Set<AnyCancellable>()
        var step = 0
        device?.connectionState
            .sink(receiveValue: { state in
                step += 1

                if state == .connected, step == 1 {
                    self.device?.disconnect()
                }

                if state == .disconnected, step == 3 {
                    self.device?.connect()
                }

                if state == .connecting, step == 4 {
                    self.device?.disconnect()
                }

                if state == .disconnected, step == 6 {
                    exp.fulfill()
                }
            })
            .store(in: &subs)

        wait(for: [exp], timeout: 20)
    }

    func testCancelPendingConnection_ViaScannerRequest_DoesNotStartConnection() throws {
        let setupExp = XCTestExpectation(description: "Does cancel existing connection")
        let exp = XCTestExpectation(description: "Disconnects while connecting")

        var subs = Set<AnyCancellable>()
        var step = 0
        device?.connectionState
            .sink(receiveValue: { state in
                step += 1

                if state == .connected, step == 1 {
                    self.device?.disconnect()
                }

                // Act: Use scanner to force a connection, then cancel it contemporaneously
                if state == .disconnected, step == 3 {
                    setupExp.fulfill()
                    self.device?.scanner?.startScan(allowDuplicates: false)

                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
                        self.device?.disconnect()
                    }
                }

                if state == .disconnected, step == 5 {
                    exp.fulfill()
                }
            })
            .store(in: &subs)

        wait(for: [exp, setupExp], timeout: 20)
    }

    func testCancelPendingConnection_ConnectPublisher_CancelDuringConnection() throws {
        let exp = XCTestExpectation(description: "Disconnects while connecting")
        let expReconnects = XCTestExpectation(description: "Reconnects")

        // Flag to insert a monitored new connection pipeline
        var step = 0

        // Subscribe to state changes before acting.
        var subs = Set<AnyCancellable>()
        device?.connectionState
            .sink(receiveValue: { state in
                step += 1
                print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~", state.debugDescription, step)

                if state == .connected, step == 1 {
                    print("__CANCEL 1__")
                    self.device?.disconnect()
                }

                if state == .disconnected, step == 3 {
                    print("__SCAN__")
                    self.discovery = self._makeDiscoveryPipeline(didConnect: expReconnects)
                        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                    self.device?.scanner?.startScan(allowDuplicates: false)
                }

                if state == .connecting, step == 4 {
                    print("__CANCEL 2__")
                    self.device?.disconnect()
                }

                if state == .disconnected, step == 6 {
                    exp.fulfill()
                }
            })
            .store(in: &subs)

        wait(for: [exp], timeout: 20)
    }
}
