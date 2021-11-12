/**
 * ScannerModel.swift
 * MetaWear-Swift
 *
 * Created by Stephen Schiffli on 1/22/18.
 * Copyright 2018 MbientLab Inc. All rights reserved.
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

/// Callbacks from ScannerModel
public protocol ScannerModelDelegate: AnyObject {
    func scannerModel(_ scannerModel: ScannerModel, didAddItemAt idx: Int)
    func scannerModel(_ scannerModel: ScannerModel, confirmBlinkingItem item: ScannerModelItem, callback: @escaping (Bool) -> Void)
    func scannerModel(_ scannerModel: ScannerModel, errorDidOccur error: Error)
}

/// Common code used for creating BLE scanner UIs where the user can select/deselect devices
public class ScannerModel {
    public weak var delegate: ScannerModelDelegate?
    /// All the discovered devices
    public var items: [ScannerModelItem] = []
    
    let scanner: MetaWearScanner
    let adTimeout: Double
    var connectingItem: ScannerModelItem?
    var connectionAttempts = Set<AnyCancellable>()
    var discoveriesSub: AnyCancellable? = nil
    
    public init(delegate: ScannerModelDelegate,
                scanner: MetaWearScanner =  MetaWearScanner.shared,
                adTimeout: Double = 5.0) {
        self.delegate = delegate
        self.scanner = scanner
        self.adTimeout = adTimeout
    }

    func startScanning() {
        scanner.startScan(allowDuplicates: true)
        discoveriesSub = scanner.didDiscover
            .receive(on: DispatchQueue.main, options: nil)
            .sink { device in
                if let item = self.items.first(where: { $0.device == device }) {
                    item.shareChangeAndResetWatchdog()
                } else {
                    self.items.append(ScannerModelItem(device, self))
                    self.delegate?.scannerModel(self, didAddItemAt: self.items.count - 1)
                }
            }
    }

    func stopScanning() {
        scanner.stopScan()
        items.forEach { $0.cancelWatchdog() }
    }

    func connect(to item: ScannerModelItem) {
        item.device.connectPublisher()
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { [weak item] _ in
                item?.shareChangeAndResetWatchdog()       // The MAC address might be unknown
            })
            .flatMap { [weak self, weak item] metaWear in
                self?._flashLEDForConfirmation(item: item).eraseToAnyPublisher() ?? _JustMW(false)
            }
            .sink { [weak self, weak item] didComplete in
                self?._resetState(for: item)

                switch didComplete {
                    case .finished: return // A requested disconnect was performed. Nothing to do.
                    case .failure(let error): // Some fault occurred
                        guard let self = self else { return }
                        self.delegate?.scannerModel(self, errorDidOccur: error)
                }

            } receiveValue: { [weak self, weak item] didConfirmBlinkingItem in
                self?._resetState(for: item)
                self?._stopLEDFlashing(for: item?.device, didAcceptItem: didConfirmBlinkingItem)
            }
            .store(in: &connectionAttempts)
    }

    private func _resetState(for item: ScannerModelItem?) {
        connectingItem = nil
        item?.isConnecting = false
        items.forEach { $0.shareChangeAndResetWatchdog() }
    }

    private func _flashLEDForConfirmation(item: ScannerModelItem?) -> AnyPublisher<Bool,MetaWearError> {
        Future { [weak self, weak item] promise in
            guard let self = self, let item = item else { return }

            item.device.ledStartFlashing(color: .green, intensity: 1.0, repeating: 60)
            self.delegate?.scannerModel(self, confirmBlinkingItem: item) { (confirmed) in
                promise(.success(confirmed))
            }
        }
        .eraseToAnyPublisher()
    }

    private func _stopLEDFlashing(for device: MetaWear?, didAcceptItem: Bool) {
        device?.ledTurnOff()
        guard let device = device, didAcceptItem == false else { return }
        mbl_mw_debug_disconnect(device.board)
    }
}



/// Simple wrapper around a MetaWear to coordinate state updates for UI in a connection screen.
public class ScannerModelItem {

    public let device: MetaWear
    public internal(set) var isConnecting = false
    public weak var parent: ScannerModel?

    /// Listen for changes that would require changes to the UI
    public private(set) lazy var stateDidChange = stateDidChangeSubject.share().eraseToAnyPublisher()
    private lazy var stateDidChangeSubject = CurrentValueSubject<ScannerModelItem,Never>(self)
    private var adWatchdog: Timer?
    
    init(_ device: MetaWear, _ parent: ScannerModel?) {
        self.device = device
        self.parent = parent
        // Schedule updates
        shareChangeAndResetWatchdog()
    }
}

public extension ScannerModelItem {

    func connect() {
        isConnecting = true
        parent?.connect(to: self)
        stateDidChangeSubject.send(self)
    }

    func cancelConnecting() {
        isConnecting = false
        device.disconnect()
        stateDidChangeSubject.send(self)
    }

    func toggleConnect() {
        if isConnecting { cancelConnecting() }
        else { connect() }
    }
}

internal extension ScannerModelItem {

    func shareChangeAndResetWatchdog() {
        DispatchQueue.main.async {
            self.stateDidChangeSubject.send(self)
            self.adWatchdog?.invalidate()
            self.adWatchdog = Timer.scheduledTimer(
                withTimeInterval: (self.parent?.adTimeout ?? 5.0) + 0.1,
                repeats: false) { [weak self] t in
                    guard let self = self else { return }
                    self.stateDidChangeSubject.send(self)
            }
        }
    }

    func cancelWatchdog() {
        DispatchQueue.main.async {
            self.adWatchdog?.invalidate()
            self.adWatchdog = nil
        }
    }
}
