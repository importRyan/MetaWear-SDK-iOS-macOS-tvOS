/**
 * MockMetaWear.swift
 * MetaWear-Swift
 *
 * Created by Stephen Schiffli on 12/14/17.
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

import CoreBluetoothMock
import MetaWearCpp

// MARK: - Create Spoofs

public extension MetaWear {

    /// Create a fake MetaWear that can be instantiated in the iOS simulator for Unit and UI Tests.
    /// - Parameters:
    ///   - name: Device name
    ///   - id: UUID string
    ///   - mac: MetaWear MAC address
    ///   - info: Preset MetaWear firmware, hardware, and model/serial numbers
    ///   - options: Application launch options
    ///   - loaded: Returns a discovered MetaWear, the mock peripheral object that can send .simulate commands, and the mock scanner that discovered the MetaWear.
    static func spoof(name: String = "unittest",
                             id: String = "CC5CEEF1-C8B9-47BF-9B5D-E7329CED353D",
                             mac: String = "BA:AA:AD:F0:00:0D",
                             info: DeviceInformation = .metaMotionC,
                             options: [String : Any]? = nil,
                             didLoad: @escaping (MetaWear, CBMPeripheralSpec, MetaWearScanner) -> Void
    ) {

        let mockSpec = CBMPeripheralSpec.makeMockMetaMotion(
            name: name, id: id, mac: mac, info: info,
            advertisingInterval: 0.25,
            connectionInterval: 0.15
        )
        let scanner = spoofScanner(options: options)

        func didDiscover(_ device: MetaWear) {
            device.mac = mac
            device.info = info
            didLoad(device, mockSpec, scanner)
        }

        CBMCentralManagerMock.simulatePeripherals([mockSpec])
        CBMCentralManagerMock.simulatePowerOn()
        mockSpec.simulateProximityChange(.immediate)
        scanner.startScan(allowDuplicates: false, callback: didDiscover)
    }

    /// Create a fake scanner that can be instantiated in the iOS simulator for Unit and UI tests.
    static func spoofScanner(options: [String : Any]? = nil) -> MetaWearScanner {
        let spoof = MockMetaWearScanner(forceMock: true)
        spoof.central = CBMCentralManagerMock(delegate: spoof, queue: spoof.bleQueue, options: options)
        return spoof
    }
}

#warning("Discuss: What's the best strategy to intercept Cpp calls for mocking?")
public class MockMetaWearScanner: MetaWearScanner {}

// MARK: - CBMPeripheral Mocks

public extension CBMPeripheralSpec {

    static func makeMockMetaMotion(name: String,
                            id: String,
                            mac: String,
                            info: DeviceInformation,
                            advertisingInterval: TimeInterval = 0.25,
                            connectionInterval: TimeInterval = 0.15
    ) -> CBMPeripheralSpec {

        let uuid = UUID(uuidString: id)!
        return CBMPeripheralSpec
            .simulatePeripheral(
                identifier: uuid,
                proximity: .outOfRange
            )
            .advertising(
                advertisementData: [
                    CBMAdvertisementDataLocalNameKey : name,
                    CBMAdvertisementDataServiceUUIDsKey : [CBMUUID.metaWearService],
                    CBMAdvertisementDataIsConnectable : true as NSNumber,
                ],
                withInterval: advertisingInterval,
                alsoWhenConnected: false
            )
            .connectable(
                name: name,
                services: [.mockMetaWearService, .mockDisService, .mockBatteryService],
                delegate: MetaMotionSpecDelegate(name: name, id: uuid, mac: mac, info: info),
                connectionInterval: connectionInterval,
                mtu: 23
            )
            .build()
    }
}


public class MetaMotionSpecDelegate {

    public let mockName: String
    public let mockID: UUID
    public let mockMac: String
    public private(set) var info: DeviceInformation
    public private(set) var modules: [UInt8: MockModule] = [:]
    // Settable via the CBMPeripheralSpec instance
    public fileprivate(set) var metaWearNotificationData: Data? = nil

    public init(name: String, id: UUID, mac: String, info: DeviceInformation) {
        self.mockName = name
        self.mockID = id
        self.mockMac = mac
        self.info = info
    }

    private func addModule(_ module: MockModule) {
        modules[module.modId] = module
    }
}

extension MetaMotionSpecDelegate: CBMPeripheralSpecDelegate {

    public func peripheralDidReceiveConnectionRequest(_ peripheral: CBMPeripheralSpec) -> Result<Void, Error> {
        addModule(MockModule.mechanicalSwitch(peripheral: peripheral))
        addModule(MockModule.led(peripheral: peripheral))
        addModule(MockModule.accelBMI160(peripheral: peripheral))
        addModule(MockModule.iBeacon(peripheral: peripheral))
        addModule(MockModule.dataProcessor(peripheral: peripheral))
        addModule(MockModule.event(peripheral: peripheral))
        addModule(MockModule.logging(peripheral: peripheral))
        addModule(MockModule.timer(peripheral: peripheral))
        addModule(MockModule.macro(peripheral: peripheral))
        addModule(MockModule.settings(peripheral: peripheral))
        addModule(MockModule.magBMM150(peripheral: peripheral))
        addModule(MockModule.gyroBMI160(peripheral: peripheral))
        addModule(MockModule.sensorFusion(peripheral: peripheral))
        addModule(MockModule.testDebug(peripheral: peripheral))
        return .success(())
    }

    public func peripheral(_ peripheral: CBMPeripheralSpec, didReceiveReadRequestFor characteristic: CBMCharacteristicMock) -> Result<Data, Error> {
        switch characteristic.uuid {
            case .disModelNumber:       return .success(info.modelNumber.data(using: .utf8)!)
            case .disSerialNumber:      return .success(info.serialNumber.data(using: .utf8)!)
            case .disFirmwareRev:       return .success(info.firmwareRevision.data(using: .utf8)!)
            case .disHardwareRev:       return .success(info.hardwareRevision.data(using: .utf8)!)
            case .disManufacturerName:  return .success(info.manufacturer.data(using: .utf8)!)
            case .batteryLife:          return .success(Data([99]))
                #warning("Is this should be a valid read path for .metaWearNotification? In Nordic's mock, prior messageSend(modId:regId:notifyEn:data) runs through CBMPeripheralSpec.simulateValueUpdate that routes that data to all CBMCentralManagers to notify peripherals to call their CBPeripheralDelegates.")
            case .metaWearNotification:
                guard let notification = metaWearNotificationData else { fallthrough }
                return .success(notification)

            default:                    return .failure(MetaWearError.operationFailed(message: "Cannot read characteristic"))
        }
    }

    public func peripheral(_ peripheral: CBMPeripheralSpec, didReceiveWriteRequestFor descriptor: CBMDescriptorMock, data: Data) -> Result<Void, Error> {
        let message = data.message
        if let module = modules[message.modId] {
            module.processMessage(message)
        } else if message.regId == 0x80 {
            // Response to mod info reads with a null response
            peripheral.messageSend(modId: message.modId, regId: message.regId, notifyEn: true, data: nil)
        }
        return .success(())
    }
}

// MARK: - Mock MetaWear Module to CBMPeripheralSpec Interaction

public extension CBMPeripheralSpec {

    func messageSend(modId: UInt8, regId: UInt8, notifyEn: Bool, data: Data?) {
        guard notifyEn, let delegate = self.connectionDelegate as? MetaMotionSpecDelegate else { return }
        var header = Data([modId, regId])
        if let data = data { header.append(data) }
        delegate.metaWearNotificationData = data
        self.simulateValueUpdate(header, for: .metaWearNotification)
    }
}


// MARK: - Mock Characteristics

extension CBMCharacteristicMock {

    static let disModelNumber = CBMCharacteristicMock(type: .disModelNumber, properties: .read)
    static let disSerialNumber = CBMCharacteristicMock(type: .disSerialNumber, properties: .read)
    static let disFirmwareRev = CBMCharacteristicMock(type: .disFirmwareRev, properties: .read)
    static let disHardwareRev = CBMCharacteristicMock(type: .disHardwareRev, properties: .read)
    static let disManufacturerName = CBMCharacteristicMock(type: .disManufacturerName, properties: .read)
    static let batteryLife = CBMCharacteristicMock(type: .batteryLife, properties: .read)
    static let metaWearNotification = CBMCharacteristicMock(type: .metaWearNotification, properties: .read)
    static let metaWearCommand = CBMCharacteristicMock(type: .metaWearCommand, properties: [.writeWithoutResponse, .write])
}

// MARK: - Mock Services

extension CBMServiceMock {

    static let mockBatteryService = CBMServiceMock(
        type: .batteryService,
        primary: false,
        characteristics: .batteryLife
    )

    static let mockMetaWearService = CBMServiceMock(
        type: .metaWearService,
        primary: true,
        characteristics: .metaWearCommand, .metaWearNotification
    )

    static let mockDisService = CBMServiceMock(
        type: .disService,
        primary: false,
        characteristics: .disModelNumber, .disSerialNumber, .disFirmwareRev, .disHardwareRev, .disManufacturerName
    )
}

// MARK: - Mock MetaWear Device Info

extension DeviceInformation {
    public static let metaMotionC = DeviceInformation(
        manufacturer:  "MbientLab Inc",
        modelNumber: "6",
        serialNumber: "FFFFFF",
        firmwareRevision: "1.3.6",
        hardwareRevision: "0.1"
    )
    public static let metaMotionR = DeviceInformation(
        manufacturer:  "MbientLab Inc",
        modelNumber: "5",
        serialNumber: "FFFFFF",
        firmwareRevision: "1.3.6",
        hardwareRevision: "0.2"
    )
    public static let metaMotionRL = DeviceInformation(
        manufacturer:  "MbientLab Inc",
        modelNumber: "5",
        serialNumber: "FFFFFF",
        firmwareRevision: "1.3.6",
        hardwareRevision: "0.6"
    )
    public static let metaMotionS = DeviceInformation(
        manufacturer:  "MbientLab Inc",
        modelNumber: "8",
        serialNumber: "FFFFFF",
        firmwareRevision: "1.3.6",
        hardwareRevision: "0.1"
    )
}
