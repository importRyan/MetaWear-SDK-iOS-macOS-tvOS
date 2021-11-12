//  © 2021 Ryan Ferrell. github.com/importRyan

import Foundation
import XCTest
@testable import MetaWear
@testable import MetaWearCpp
import Combine

// MARK: - DRY Utilities for Testing MetaWear Devices

protocol MetaWearTestCase: XCTestCase {
    var device: MetaWear? { get set }
    var discovery: AnyCancellable? { get set }
    var disconnectExpectation: XCTestExpectation? { get set }

    func connectToAnyNearbyMetaWear()
    func expectDisconnection() throws
    func prepareDeviceForTesting() throws
}

// MARK: - Setup

let scanner = MetaWearScanner.sharedRestore

extension MetaWearTestCase {

    /// Expect that the MetaWear reports a disconnection when requested.
    ///
    func expectDisconnection() throws {
        let exp = try XCTUnwrap(disconnectExpectation)
        device?.disconnect()
        wait(for: [exp], timeout: 60)
    }

    /// Print out identifying information (and test that information is present)
    ///
    func prepareDeviceForTesting() throws {
        let device = try XCTUnwrap(device)
        print(device.mac ?? "In MetaBoot")
        print(try XCTUnwrap(device.info), device.name)
        device.resetToFactoryDefaults()
    }

    /// Connect to the first nearby MetaWear discovered with decent signal strength within 60 seconds or fails. Sets up for disconnect expectation.
    ///
    /// Split into helper methods so some methods can test cancellation.
    ///
    func connectToAnyNearbyMetaWear() {
        let didConnect = XCTestExpectation(description: "Connecting")
        self.disconnectExpectation = XCTestExpectation(description: "Disconnecting")
        self.discovery = _makeDiscoveryPipeline(didConnect: didConnect)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        scanner.startScan(allowDuplicates: true)
        wait(for: [didConnect], timeout: 20)
    }

    func _makeDiscoveryPipeline(didConnect: XCTestExpectation) -> AnyPublisher<MetaWear,MetaWearError> {
        MetaWearScanner.sharedRestore.didDiscover
            .filter { $0.rssi > -70 }
            .handleEvents(receiveOutput: {
                scanner.stopScan()
                guard (self.device === $0) == false else { return }
                self.device = $0
                self.device?.logDelegate = ConsoleLogger.shared
            })
            .flatMap { metawear -> AnyPublisher<MetaWear,MetaWearError> in
                return metawear.connectPublisher()
                    .handleEvents(receiveOutput: { [weak didConnect] wear in
                        didConnect?.fulfill()
                    })
                    .handleEvents(receiveCompletion: { completion in
                        switch completion {
                            case .finished:
                                self.disconnectExpectation?.fulfill()
                            case .failure(let error):
                                self.continueAfterFailure = false
                                XCTFail(error.localizedDescription)
                        }
                    })
                    .print()
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    /// Inverted timeout for manual tests
    func wait(forVisualInspection: TimeInterval, label: String = #function, test: @escaping (MetaWear, XCTestExpectation) throws -> Void) throws {
        let device = try XCTUnwrap(device)
        let delayForVisualSighting = XCTestExpectation(description: label)
        delayForVisualSighting.isInverted = true
        try test(device, delayForVisualSighting)
        wait(for: [delayForVisualSighting], timeout: forVisualInspection)
    }

    /// Timeout sugar
    func wait(timeout: TimeInterval, label: String = #function, test: @escaping (MetaWear, XCTestExpectation, inout Set<AnyCancellable>) throws -> Void) throws {
        let device = try XCTUnwrap(device)
        let exp = XCTestExpectation(description: label)
        var subs = Set<AnyCancellable>()
        try test(device, exp, &subs)
        wait(for: [exp], timeout: timeout)
    }
}

// MARK: - Utility Functions

func FailOnError<E>(_ completion: Subscribers.Completion<E>) {
    guard case let .failure(error) = completion else { return }
    XCTFail(error.localizedDescription)
}
