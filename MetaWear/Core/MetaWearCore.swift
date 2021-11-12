/**
 * MetaWear.swift
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

import CoreBluetooth
import MetaWearCpp
import Combine

/// Each MetaWear object corresponds a physical MetaWear board. It contains
/// methods for connecting, disconnecting, saving and restoring state.
///
public class MetaWear: NSObject {

    // MARK: - References

    /// To prevent crashes, use this queue for all MetaWearCpp library calls.
    public var apiAccessQueue: DispatchQueue { scanner?.bleQueue ?? DispatchQueue.global() }

    /// This device's CoreBluetooth object
    public let peripheral: CBPeripheral

    /// Scanner that discovered this device
    public private(set) weak var scanner: MetaWearScanner?

    /// Receives device activity
    public var logDelegate: LogDelegate?

    /// Pass to MetaWearCpp functions
    public private(set) var board: OpaquePointer!

    /// Convenience. Not accessed or managed by this SDK.
    public lazy var publicSubs = Set<AnyCancellable>()


    // MARK: - Connection State

    /// Has BLE connection and an initialized MetaWearCpp library
    public private(set) var isConnectedAndSetup = false

    /// Whether advertised or discovered as a MetaBoot
    public private(set) var isMetaBoot = false

    /// Stream of connecting, connected, and disconnected events.
    public let connectionState: AnyPublisher<CBPeripheralState, Never>


    // MARK: - Signal (refreshed by `MetaWearScanner` activity)

    /// Latest signal strength and advertisement packet data, while the `MetaWearScanner` is active.
    public let advertisementReceived: AnyPublisher<(rssi: Int, advertisementData: [String:Any]), Never>

    /// Last advertisement packet data.
    public var advertisementData: [String : Any] {
        get { Self._adQueue.sync { _adData } }
    }

    /// Received signal strength indicator. Updates while `MetaWearScanner` is active. Set on the `apiAccessQueue`.
    public private(set) var rssi: Int = 0


    // MARK: - Device Identity

    /// MAC address (available after first connection)
    public internal(set) var mac: String?

    /// Model, serial, firmware, hardware, and manufacturer details (available after first connection)
    public internal(set) var info: DeviceInformation?

    /// Latest advertised name. Note: The CBPeripheral.name property might be cached.
    public var name: String {
        return Self._adQueue.sync {
            let adName = _adData[CBAdvertisementDataLocalNameKey] as? String
            return adName ?? peripheral.name ?? "MetaWear"
        }
    }

    // MARK: - Internal Properties

    // Delegate responses to async pipelines in setup/operation
    fileprivate var _setupMacToken: AnyCancellable? = nil
    fileprivate var _connectionStateSubject = CurrentValueSubject<CBPeripheralState,Never>(.disconnected)
    fileprivate var _connectSubjects: [PassthroughSubject<MetaWear, MetaWearError>] = []
    fileprivate var _disconnectSubjects: [PassthroughSubject<MetaWear, MetaWearError>] = []
    fileprivate var _readCharacteristicSubjects: [CBCharacteristic: [PassthroughSubject<Data, MetaWearError>]] = [:]
    fileprivate var _rssiSubjects: [PassthroughSubject<Int, MetaWearError>] = []

    // CBCharacteristics discovery + device setup
    fileprivate var _gattCharMap: [MblMwGattChar: CBCharacteristic] = [:]
    fileprivate var _serviceCount = 0
    fileprivate var _subsDiscovery = Set<AnyCancellable>()

    // Writes
    fileprivate var _commandCount = 0
    fileprivate var _writeQueue: [(data: Data, characteristic: CBCharacteristic, type: CBCharacteristicWriteType)] = []

    // MblMwBtleConnection callbacks for read/writeGattChar, _enableNotifications, and _onDisconnect functions
    fileprivate var _onDisconnectCallback: MblMwFnVoidVoidPtrInt?
    fileprivate var _onReadCallbacks: [CBCharacteristic: MblMwFnIntVoidPtrArray] = [:]
    fileprivate var _onDataCallbacks: [CBCharacteristic: MblMwFnIntVoidPtrArray] = [:]
    fileprivate var _subscribeCompleteCallbacks: [CBCharacteristic: MblMwFnVoidVoidPtrInt] = [:]

    /// Read/set from advertisement queue `Self.adQueue`
    fileprivate static let _adQueue = DispatchQueue(label: "com.mbientlab.adQueue")
    fileprivate var _rssiHistory: [(Date, Double)] = []
    fileprivate var _adData: [String : Any] = [:]
    fileprivate let _adReceivedSubject = CurrentValueSubject<(rssi: Int, advertisementData: [String:Any]), Never>( (rssi: -80, advertisementData: [String:Any]()) )


    /// Please use `MetaWearScanner` to initialize MetaWears properly. To subclass the scanner, you may need to use this initializer.
    ///
    /// - Parameters:
    ///   - peripheral: Discovered `CBPeripheral`
    ///   - scanner: Scanner that discovered the peripheral
    ///
    public init(peripheral: CBPeripheral, scanner: MetaWearScanner) {
        self.peripheral = peripheral
        self.scanner = scanner
        self.connectionState = self._connectionStateSubject
            .share()
            .erase(subscribeOn: scanner.bleQueue)

        self.advertisementReceived = self._adReceivedSubject
            .subscribe(on: Self._adQueue)
            .receive(on: scanner.bleQueue)
            .share()
            .eraseToAnyPublisher()

        super.init()
        self.peripheral.delegate = self
        var connection = MblMwBtleConnection(context: bridge(obj: self),
                                             write_gatt_char: _writeGattChar,
                                             read_gatt_char: _readGattChar,
                                             enable_notifications: _enableNotifications,
                                             on_disconnect: _onDisconnect)
        self.board = mbl_mw_metawearboard_create(&connection)
        // TODO: evaluate if the timeout provides value
        mbl_mw_metawearboard_set_time_for_response(self.board, 0)
        self.mac = UserDefaults.MetaWearCore.getMac(for: self)
    }
}

// MARK: - Public API (Connection Process)

public extension MetaWear {

    /// Connect to this MetaWear and initialize the C++ library.
    ///
    /// Enqueues a connection request to the parent MetaWearScanner.
    /// For connection state changes, subscribe to `connectionState` or
    /// use the `connectPublisher()` variant.
    ///
    func connect() {
        apiAccessQueue.async { [weak self] in
            guard let self = self, self.isConnectedAndSetup == false else { return }
            self.scanner?.connect(self)
            self._connectionStateSubject.send(.connecting)
        }
    }

    /// Connect to this MetaWear and initialize the C++ library.
    ///
    /// This publisher enqueues a connection request to the
    /// scanner that discovered it. It behaves as follows:
    /// - on connection (or if already), sends a reference to self
    /// - on disconnect, completes without error
    /// - on a setup fault, completes with error
    /// - if you cancel the `AnyCancellable`, attempts device disconnect
    /// - subscribes and sends on the `apiAccessQueue`
    ///
    /// Internally, this is an erased `PassthroughSubject`
    /// that is cached for `CBPeripheralDelegate` methods
    /// to call as setup progresses.
    ///
    /// - Returns: On the `apiAccessQueue` an error, device reference (success), or completion on error-less disconnect
    ///
    func connectPublisher() -> MetaPublisher<MetaWear> {
        Just(isConnectedAndSetup)
            .flatMap { [weak self] isConnected -> AnyPublisher<MetaWear,MetaWearError> in
                MetaWear._buildConnectPublisher(self, isConnected)
            }
            .handleEvents(receiveCancel: { [weak self] in
                self?.cancelConnection()
            })
            .share()
            .erase(subscribeOn: apiAccessQueue)
    }

    /// Disconnect or cancel a connection attempt
    ///
    func cancelConnection() {
        scanner?.cancelConnection(self)
    }
}


// MARK: - Public API (Reconnection to Known Devices)

public extension MetaWear {

    /// Before reconnecting to a device, restore data for Cpp library using data you previously saved to the `uniqueURL`. You are responsible for writing data.
    ///
    func loadSavedStateFromUniqueURL() {
        if let data = try? Data(contentsOf: uniqueUrl) {
            deserialize([UInt8](data))
        }
    }

    /// Add this to a persistent list retrieved with `MetaWearScanner.retrieveSavedMetaWearsAsync(...)`
    ///
    func remember() {
        scanner?.remember(self)
    }

    /// Remove this from the persistent list `MetaWearScanner.retrieveSavedMetaWearsAsync(...)`
    ///
    func forget() {
        scanner?.forget(self)
    }

    /// Dump all MetaWearCpp library state.
    ///
    func serialize() -> [UInt8] {
        var count: UInt32 = 0
        let start = mbl_mw_metawearboard_serialize(board, &count)
        let data = Array(UnsafeBufferPointer(start: start, count: Int(count)))
        mbl_mw_memory_free(start)
        return data
    }

    /// Restore MetaWearCpp library state, must be called before `connectAndSetup()`.
    ///
    func deserialize(_ _data: [UInt8]) {
        var data = _data
        mbl_mw_metawearboard_deserialize(board, &data, UInt32(data.count))
    }

    /// Create a file name unique to this device, based on its `CBPeripheral` identifier UUID, inside the user's Application Support directory inside the folder `com.mbientlab.devices`.
    ///
    var uniqueUrl: URL {
        var url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.mbientlab.devices", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        url.appendPathComponent(peripheral.identifier.uuidString + ".file")
        return url
    }
}


// MARK: - Public API (Signal Strength)

public extension MetaWear {

    /// Filter the last received RSSI values into a less jumpy depiction of signal strength.
    ///
    /// - Parameter lastNSeconds: Averaging period (default 5 seconds)
    /// - Returns: Averaged value. Falls to zero when disconnected and no recent values fall into the averaging window.
    ///
    func averageRSSI(lastNSeconds: Double = 5.0) -> Double? {
        Self._adQueue.sync {
            let filteredRSSI = _rssiHistory.prefix { -$0.0.timeIntervalSinceNow < lastNSeconds }
            guard filteredRSSI.count > 0 else { return nil }
            let sumArray = filteredRSSI.reduce(0.0) { $0 + $1.1 }
            return sumArray / Double(filteredRSSI.count)
        }
    }

    /// Retrieves a refreshed RSSI value for the peripheral while it is connected
    /// - Returns: The update received in `didReadRSSI` of `CBPeripheralDelegate`. Fails if not connected upon subscription.
    ///
    func readRSSI() -> MetaPublisher<Int> {
        ifConnected()
            .flatMap { [weak self] state -> AnyPublisher<Int,MetaWearError>  in
                let subject = PassthroughSubject<Int,MetaWearError>()
                self?._rssiSubjects.append(subject)
                return subject.eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private func _updateRSSIValues(RSSI: NSNumber) {
        self.apiAccessQueue.async { [weak self] in
            self?.rssi = RSSI.intValue
        }

        Self._adQueue.async { [weak self] in
            guard let self = self else { return }
            // Timestamp and save the last N RSSI samples
            let rssi = RSSI.doubleValue
            if rssi < 0 {
                self._rssiHistory.insert((Date(), RSSI.doubleValue), at: 0)
            }
            if self._rssiHistory.count > 10 {
                self._rssiHistory.removeLast()
            }
        }
    }
}


// MARK: - Public API (Device Information)

public extension MetaWear {

    /// Requests up-to-date information about this MetaWear device.
    /// - Returns: Identifiers and state for the board.
    ///
    func getDeviceInformation() -> MetaPublisher<DeviceInformation> {
        Publishers.Zip(readManufacturer(), readModelNumber())
            .zip(readSerialNumber(), readFirmwareRev(), readHardwareRev(), { mm, serial, firm, hard in
                (mm.0, mm.1, serial, firm, hard)
            })
            .map(DeviceInformation.init)
            .eraseToAnyPublisher()
    }

    /// Requests the board's model number.
    /// - Returns: Preset string value.
    ///
    func readModelNumber() -> AnyPublisher<String,MetaWearError> {
        _readDisService(characteristic: .disModelNumber)
    }

    /// Requests the board's serial number.
    /// - Returns: Preset string value.
    ///
    func readSerialNumber() -> AnyPublisher<String,MetaWearError> {
        _readDisService(characteristic: .disSerialNumber)
    }

    /// Requests the board's hardware revision.
    /// - Returns: Preset string value.
    ///
    func readHardwareRev() -> AnyPublisher<String,MetaWearError> {
        _readDisService(characteristic: .disHardwareRev)
    }

    /// Requests the board's firmware version.
    /// - Returns: Current string value.
    ///
    func readFirmwareRev() -> AnyPublisher<String,MetaWearError> {
        _readDisService(characteristic: .disFirmwareRev)
    }

    /// Requests the board's manufacturer name.
    /// - Returns: Preset string value.
    ///
    func readManufacturer() -> AnyPublisher<String,MetaWearError> {
        _readDisService(characteristic: .disManufacturerName)
    }

    /// Request a refreshed value for the target characteristic.
    ///
    /// - Parameters:
    ///   - characteristic: Convenient preset for MetaWear characteristics and corresponding service.
    ///
    /// - Returns: A completing publisher for data supplied by the `CoreBluetooth` framework. Requests are queued for fulfillment by the `CBPeripheralDelegate` `peripheral(:didUpdateValueFor:error:)` method.
    ///
    func readCharacteristic(_ characteristic: MetaWear.Characteristic) -> MetaPublisher<Data> {
        readCharacteristic(characteristic.service.cbuuid, characteristic.cbuuid)
    }

    /// Request a refreshed value for the target service and characteristic.
    ///
    /// - Parameters:
    ///   - serviceUUID: See `CBUUID` static presets for MetaWear service options.
    ///   - characteristicUUID: See `CBUUID` static presets for MetaWear characteristic options.
    ///
    /// - Returns: A completing publisher for data supplied by the `CoreBluetooth` framework. Requests are queued for fulfillment by the `CBPeripheralDelegate` `peripheral(:didUpdateValueFor:error:)` method.
    ///
    func readCharacteristic(_ serviceUUID: CBUUID, _ characteristicUUID: CBUUID) -> MetaPublisher<Data> {
        getCharacteristic(serviceUUID, characteristicUUID)
            .publisher
            .flatMap { [weak self] characteristic -> AnyPublisher<Data,MetaWearError> in
                let subject = PassthroughSubject<Data, MetaWearError>()
                self?._readCharacteristicSubjects[characteristic, default: []].append(subject)
                self?.peripheral.readValue(for: characteristic)
                return subject.eraseToAnyPublisher()
            }
            .erase(subscribeOn: apiAccessQueue)
    }

    /// **Returns synchronously on the calling queue. Call only from `apiAccessQueue`.** Retrieves a characteristic contained in the most recently refreshed list of `CBService`.
    ///
    /// - Parameters:
    ///   - serviceUUID: See `CBUUID` static presets for MetaWear service options.
    ///   - characteristicUUID: See `CBUUID` static presets for MetaWear characteristic options.
    /// - Returns: On the calling queue. The characteristic or failure for `CBUUID` input that are invalid or not found.
    ///
    func getCharacteristic(_ serviceUUID: CBUUID,_ characteristicUUID: CBUUID) -> Result<CBCharacteristic, MetaWearError> {
        guard let service = self.peripheral.services?.first(where: { $0.uuid == serviceUUID })
        else { return .failure(.operationFailed("Service not found")) }

        guard let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID })
        else { return .failure(.operationFailed("Characteristics not found")) }

        return .success(characteristic)
    }
}


// MARK: - Conformance to `CBPeripheralDelegate` for device setup

extension MetaWear: CBPeripheralDelegate {

    // Device setup step 1
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

        guard error == nil, let services = peripheral.services else {
            _invokeConnectionHandlers(error: error!, cancelled: false)
            cancelConnection()
            return
        }

        _gattCharMap = [:]
        _serviceCount = 0
        for service in services {
            switch service.uuid {
                case .metaWearService:
                    isMetaBoot = false
                    peripheral.discoverCharacteristics([
                        .metaWearCommand,
                        .metaWearNotification
                    ], for: service)

                case .batteryService:
                    peripheral.discoverCharacteristics([
                        .batteryLife
                    ], for: service)

                case .disService:
                    peripheral.discoverCharacteristics([
                        .disManufacturerName,
                        .disSerialNumber,
                        .disHardwareRev,
                        .disFirmwareRev,
                        .disModelNumber
                    ], for: service)

                case .metaWearDfuService:
                    // Expected service, but we don't need to discover its characteristics
                    isMetaBoot = true

                default:
                    let error = MetaWearError.operationFailed("MetaWear device contained an unexpected BLE service. Please try connection again.")
                    self._invokeConnectionHandlers(error: error, cancelled: false)
                    self._invokeDisconnectionHandlers(error: error)
                    self.cancelConnection()
                    break // Don't evaluate other services
            }
        }
    }

    // Device setup step 2
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        guard error == nil else {
            _invokeConnectionHandlers(error: error!, cancelled: false)
            cancelConnection()
            return
        }

        guard isMetaBoot == false else {
            _didDiscoverCharacteristicsForMetaBoot()
            return
        }

        _serviceCount += 1
        guard _serviceCount == 3 else { return }

        _setupCppSDK_start()
    }

    // Responses to RSSI requests
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error = error {
            _rssiSubjects.forEach {
                $0.send(completion: .failure( .operationFailed("didReadRSSI \(error.localizedDescription)") ))
            }
        } else {
            _rssiSubjects.forEach {
                $0.send(RSSI.intValue)
                $0.send(completion: .finished)
            }
        }
        _rssiSubjects.removeAll()
        _updateRSSIValues(RSSI: RSSI)
    }

    // Responses to readValue requests.
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        logDelegate?._didUpdateValueFor(characteristic: characteristic, error: error)
        guard error == nil, let data = characteristic.value, data.count > 0 else { return }

        if let onRead = _onReadCallbacks[characteristic] {
            data.withUnsafeBytes { rawBufferPointer -> Void in
                let unsafeBufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
                let unsafePointer = unsafeBufferPointer.baseAddress!
                let _ = onRead(UnsafeRawPointer(board), unsafePointer, UInt8(data.count))
            }
            _onReadCallbacks.removeValue(forKey: characteristic)
        }

        if let onData = _onDataCallbacks[characteristic] {
            data.withUnsafeBytes { rawBufferPointer -> Void in
                let unsafeBufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
                let unsafePointer = unsafeBufferPointer.baseAddress!
                let _ = onData(UnsafeRawPointer(board), unsafePointer, UInt8(data.count))
            }
        }

        if let promises = _readCharacteristicSubjects.removeValue(forKey: characteristic) {
            promises.forEach {
                $0.send(data)
                $0.send(completion: .finished)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        logDelegate?.logWith(.info, message: "didUpdateNotificationStateFor \(characteristic)")
        _subscribeCompleteCallbacks[characteristic]?(UnsafeRawPointer(board), error == nil ? 0 : 1)
    }

    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        _writeIfNeeded()
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {}

}

// MARK: - Internals (Connection w/ `MetaWearScanner` as `CBCentralManagerDelegate`)

internal extension MetaWear {

    /// Kicks off device setup by discovering services when the `MetaWearScanner`, as `CBCentralManagerDelegate`, receives `didConnect`.
    ///
    func _scannerDidConnect() {
        peripheral.discoverServices([
            .metaWearService,
            .metaWearDfuService,
            .batteryService,
            .disService
        ])
        logDelegate?.logWith(.info, message: "didConnect")
    }

    /// Updates state when the `MetaWearScanner`, as `CBCentralManagerDelegate`, receives `didFailToConnect`.
    ///
    func _scannerDidFailToConnect(error: Error?) {
        _invokeConnectionHandlers(error: error, cancelled: false)
        _invokeDisconnectionHandlers(error: error)
        logDelegate?.logWith(.info, message: "didFailToConnect: \(String(describing: error))")
    }

    /// Updates state when the `MetaWearScanner`, as `CBCentralManagerDelegate`, receives `didDisconnectPeripheral` or `centralManagerDidUpdateState` where the state is not `.poweredOn`.
    ///
    func _scannerDidDisconnectPeripheral(error: Error?) {
        _invokeConnectionHandlers(error: error, cancelled: error == nil)
        _invokeDisconnectionHandlers(error: error)
        logDelegate?.logWith(.info, message: "didDisconnectPeripheral: \(String(describing: error))")
    }

    /// Updates state when the `MetaWearScanner` discovered a MetaWear in `didDiscover` method of `CBCentralManagerDelegate`.
    ///
    func _scannerDidDiscover(advertisementData: [String : Any], rssi RSSI: NSNumber) {
        Self._adQueue.sync {
            _adReceivedSubject.send((rssi,advertisementData))

            self._adData = advertisementData

            if let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
                self.apiAccessQueue.async {
                    self.isMetaBoot = services.contains(.metaWearDfuService)
                }
            }
        }
        _updateRSSIValues(RSSI: RSSI)
        logDelegate?.logWith(.info, message: "didDiscover: \(RSSI)")
    }

}


// MARK: - Internals (Device Setup and Connection)

private extension MetaWear {

    func _didDiscoverCharacteristicsForMetaBoot() {
        getDeviceInformation()
            .sink { completion in
                guard case let .failure(error) = completion else { return }
                self._invokeConnectionHandlers(error: error, cancelled: false)
            } receiveValue: { info in
                self.info = info
            }
            .store(in: &_subsDiscovery)
    }

    func _setupCppSDK_start() {
        mbl_mw_metawearboard_initialize(board, bridgeRetained(obj: self)) { (context, board, errorCode) in
            let device: MetaWear = bridgeTransfer(ptr: context!)

            let initializedCorrectly = errorCode == 0
            guard initializedCorrectly else {
                device._setupCppSDK_didFail("Board initialization failed: \(errorCode)")
                return
            }

            // Grab `DeviceInformation`
            let rawInfo = mbl_mw_metawearboard_get_device_information(device.board)
            device.info = rawInfo?.pointee.convert()
            mbl_mw_memory_free(UnsafeMutableRawPointer(mutating: rawInfo))

            device._setupCppSDK_finalize()
        }
    }

    func _setupCppSDK_finalize() {
        guard mac == nil else {
            _setupCppSDK_didSucceed()
            return
        }

        _setupMacToken?.cancel()
        _setupMacToken = ReadNoCheck(.macAddress)
            .sink { [weak self] completion in
                switch completion {
                    case .finished: return
                    case .failure(let error):
                        self?._setupCppSDK_didFail(error.chainableDescription)
                }
            } receiveValue: { [weak self] macString in
                guard let self = self else { return }
                self.mac = macString
                UserDefaults.MetaWearCore.setMac(macString, for: self)
                self._setupCppSDK_didSucceed()
            }
    }

    func _setupCppSDK_didSucceed() {
        apiAccessQueue.async { [weak self] in
            self?._invokeConnectionHandlers(error: nil, cancelled: false)
        }
    }

    func _setupCppSDK_didFail(_ msg: String) {
        apiAccessQueue.async { [weak self] in
            let error = MetaWearError.operationFailed(msg)
            self?._invokeConnectionHandlers(error: error, cancelled: false)
            self?.cancelConnection()
        }
    }

    /// Complete connection-related pipelines upon a cancel request or an error during device setup methods (e.g., in `CBCharacteristic` discovery). If connection is successful, move the pipelines into the disconnect promise queue.
    ///
    func _invokeConnectionHandlers(error: Error?, cancelled: Bool) {
        assert(DispatchQueue.isBleQueue)
        if cancelled == false && error == nil {
            self.isConnectedAndSetup = true
            self._connectionStateSubject.send(.connected)
        }
        // Clear out the connectionSources array now because we use the
        // length as an indication of a pending operation, and if any of
        // the callback call connectAndSetup, we need the right thing to happen
        let localConnectionSubjects = _connectSubjects
        _connectSubjects.removeAll(keepingCapacity: true)

        if let error = error {
            localConnectionSubjects.forEach {
                $0.send(completion: .failure( .operationFailed(error.localizedDescription) ))
            }

        } else if cancelled {
            localConnectionSubjects.forEach { $0.send(self) }
        } else {
            _disconnectSubjects.append(contentsOf: localConnectionSubjects)
        }
    }

    /// Terminate connection-related pipelines or read promises upon a disconnect request or event or an error during setup methods.
    ///
    func _invokeDisconnectionHandlers(error: Error?) {
        assert(DispatchQueue.isBleQueue)

        isConnectedAndSetup = false

        // Inform the C++ SDK
        _onDisconnectCallback?(UnsafeRawPointer(board), 0)
        _onDisconnectCallback = nil

        let isUnexpected = (error != nil) && (error as? CBError)?.code != .peripheralDisconnected
        _disconnectSubjects.forEach {
            isUnexpected
            ? $0.send(completion: .failure( .operationFailed(error!.localizedDescription) ))
            : $0.send(completion: .finished)
        }
        _disconnectSubjects.removeAll(keepingCapacity: true)
        _connectionStateSubject.send(.disconnected)

        _gattCharMap = [:]
        _subscribeCompleteCallbacks = [:]
        _onDataCallbacks = [:]
        _onReadCallbacks = [:]

        _readCharacteristicSubjects.forEach { $0.value.forEach {
            isUnexpected
            ? $0.send(completion: .failure( .operationFailed("Disconnected before read finished") ))
            : $0.send(completion: .finished)
        }}
        _readCharacteristicSubjects.removeAll(keepingCapacity: true)

        _subsDiscovery.forEach { $0.cancel() }
        _setupMacToken?.cancel()

        _writeQueue.removeAll()
        _commandCount = 0
    }

    static func _buildConnectPublisher(_ weakSelf: MetaWear?, _ isConnected: Bool) -> AnyPublisher<MetaWear,MetaWearError> {
        let subject = PassthroughSubject<MetaWear, MetaWearError>()

        // NOT CONNECTED - Schedule connect command
        if isConnected == false {

            // If the only request, connect. Otherwise, skip as a setup operation is pending.
            weakSelf?._connectSubjects.append(subject)
            if weakSelf?._connectSubjects.endIndex == 1 {
                weakSelf?.scanner?.connect(weakSelf)
                weakSelf?._connectionStateSubject.send(.connecting)
            }

            return subject.eraseToAnyPublisher()
        }

        // ALREADY CONNECTED — Link returned publisher into disconnect messages
        weakSelf?._disconnectSubjects.append(subject)

        // SEND SELF REFERENCE TO CLARIFY STATE (silence would be ambiguous)
        return subject
            .handleEvents(receiveSubscription: { [weak subject, weak weakSelf] _ in
                guard let self = weakSelf else { return }
                subject?.send(self)
            })
            .erase(subscribeOn: weakSelf?.apiAccessQueue ?? .global())
    }

}


// MARK: - Internals (GattChar / write / non-self closures for `MblMwBtleConnection` initialization)

private extension MetaWear {

    func _writeIfNeeded() {
        guard !_writeQueue.isEmpty else { return }
        var canSendWriteWithoutResponse = true
        // Starting from iOS 11 and MacOS 10.13 we have a robust way to check
        // if we can send a message without response and not loose it, so no longer
        // need to arbitrary send every 10th message with response
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *) {
            // The peripheral.canSendWriteWithoutResponse often returns false before
            // even we start sending, so always send the first
            if _commandCount != 0 {
                guard peripheral.canSendWriteWithoutResponse else { return }
            }
        } else {
            // Throttle by having every Nth request wait for response
            canSendWriteWithoutResponse = !(_commandCount % 10 == 0)
        }
        _commandCount += 1
        let (data, charToWrite, requestedType) = _writeQueue.removeFirst()
        let type: CBCharacteristicWriteType = canSendWriteWithoutResponse ? requestedType : .withResponse
        logDelegate?.logWith(.info, message: "Writing \(type == .withoutResponse ? "NO-RSP" : "   RSP"): \(charToWrite.uuid) \(data.hexEncodedString())")
        peripheral.writeValue(data, for: charToWrite, type: type)
        _writeIfNeeded()
    }

    func _getCBCharacteristic(_ characteristicPtr: UnsafePointer<MblMwGattChar>?) -> CBCharacteristic? {
        guard let characteristicPtr = characteristicPtr else { return nil }

        if let characteristic = _gattCharMap[characteristicPtr.pointee] {
            return characteristic
        }

        let serviceUUID = characteristicPtr.pointee.serviceUUID
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else { return nil }

        let characteristicUUID = characteristicPtr.pointee.characteristicUUID
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID }) else { return nil }

        _gattCharMap[characteristicPtr.pointee] = characteristic
        return characteristic
    }

    /// Already queue-bound in readCharacteristic
    func _readDisService(characteristic: CBUUID) -> MetaPublisher<String> {
        readCharacteristic(.disService, characteristic)
            .map { String(data: $0, encoding: .utf8) ?? "" }
            .eraseToAnyPublisher()
    }
}

fileprivate func _writeGattChar(context: UnsafeMutableRawPointer?,
                                caller: UnsafeRawPointer?,
                                writeType: MblMwGattCharWriteType,
                                characteristicPtr: UnsafePointer<MblMwGattChar>?,
                                valuePtr: UnsafePointer<UInt8>?,
                                length: UInt8) {
    let device: MetaWear = bridge(ptr: context!)
    if let charToWrite = device._getCBCharacteristic(characteristicPtr) {
        let data = Data(bytes: valuePtr!, count: Int(length))
        let type: CBCharacteristicWriteType = writeType == MBL_MW_GATT_CHAR_WRITE_WITH_RESPONSE ? .withResponse : .withoutResponse
        if DispatchQueue.isBleQueue {
            device._writeQueue.append((data: data, characteristic: charToWrite, type: type))
            device._writeIfNeeded()
        } else {
            device.apiAccessQueue.async {
                device._writeQueue.append((data: data, characteristic: charToWrite, type: type))
                device._writeIfNeeded()
            }
        }
    }
}


fileprivate func _readGattChar(context: UnsafeMutableRawPointer?,
                               caller: UnsafeRawPointer?,
                               characteristicPtr: UnsafePointer<MblMwGattChar>?,
                               callback: MblMwFnIntVoidPtrArray?) {
    let device: MetaWear = bridge(ptr: context!)
    if let charToRead = device._getCBCharacteristic(characteristicPtr) {
        // Save the callback
        device._onReadCallbacks[charToRead] = callback
        // Request the read
        device.peripheral.readValue(for: charToRead)
    }
}

fileprivate func _enableNotifications(context: UnsafeMutableRawPointer?,
                                      caller: UnsafeRawPointer?,
                                      characteristicPtr: UnsafePointer<MblMwGattChar>?,
                                      onData: MblMwFnIntVoidPtrArray?,
                                      subscribeComplete: MblMwFnVoidVoidPtrInt?) {
    let device: MetaWear = bridge(ptr: context!)
    if let charToNotify = device._getCBCharacteristic(characteristicPtr) {
        // Save the callbacks
        device._onDataCallbacks[charToNotify] = onData
        device._subscribeCompleteCallbacks[charToNotify] = subscribeComplete
        // Turn on the notification stream
        device.peripheral.setNotifyValue(true, for: charToNotify)
    } else {
        subscribeComplete?(caller, 1)
    }
}

fileprivate func _onDisconnect(context: UnsafeMutableRawPointer?,
                               caller: UnsafeRawPointer?,
                               handler: MblMwFnVoidVoidPtrInt?) {
    let device: MetaWear = bridge(ptr: context!)
    device._onDisconnectCallback = handler
}
