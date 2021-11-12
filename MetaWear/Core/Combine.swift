////Copyright

import Foundation
import Combine
import CoreBluetooth

/// A type-erased publisher that subscribes and returns on its parent's BLE queue.
///
public typealias MetaPublisher<Output> = AnyPublisher<Output, MetaWearError>

// MARK: - Convenience Sugar

extension MetaWear {

    /// Convenience publisher for a one-time read of a board signal.
    ///
    /// - Parameters:
    ///   - signal: Type-safe preset for `MetaWear` board signals
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected upon subscription.
    ///
    public func readOnceIfSetup<T>(_ signal: MWSignal<T>) -> MetaPublisher<T> {
        guard let pointer = signal.from(board) else {
            let error = MetaWearError.operationFailed("Board unavailable when reading \(signal.name) signal.")
            return Fail(outputType: T.self, failure: error)
                .erase(subscribeOn: self.apiAccessQueue)
        }
        return ifSetup(publish: pointer)
            .flatMap {
                $0
                    .readOnce(as: T.self)
                    .mapError { _ in // Replace the generic type failure message
                        MetaWearError.operationFailed("Failed reading \(signal.name) signal.")
                    }
            }
            .erase(subscribeOn: self.apiAccessQueue)
    }

    /// Convenience publisher for a one-time read of a board signal.
    ///
    /// - Parameters:
    ///   - signal: Board signal produced by a C++ bridge command like `mbl_mw_settings_get_battery_state_data_signal(board)`
    ///   - type: Type you expect to cast (will crash if incorrect)
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected upon subscription.
    ///
    public func readOnceIfSetup<T>(signal: OpaquePointer, as type: T.Type) -> MetaPublisher<T> {
        ifSetup(publish: signal)
            .flatMap { $0.readOnce(as: T.self) }
            .erase(subscribeOn: self.apiAccessQueue)
    }

    public func ifSetup(publish: OpaquePointer) -> MetaPublisher<OpaquePointer> {
        BLELazyFuture { [weak self] promise in
            let error: MetaWearError = .operationFailed("Connect the MetaWear before performing this operation.")
            switch self?.isConnectedAndSetup {
                case true: promise(.success(publish))
                default: promise(.failure(error))
            }
        }
    }

    public func ifConnected() -> MetaPublisher<CBPeripheralState> {
        BLELazyFuture { [weak self] promise in
            let error: MetaWearError = .operationFailed("Connect the MetaWear before performing this operation.")
            switch self?.peripheral.state {
                case .connected: promise(.success(.connected))
                default: promise(.failure(error))
            }
        }
    }
}


// MARK: - Public - General Operators

public extension Publisher {

    /// Sugar to ensure operations upstream of this are performed async on the provided queue.
    ///
    func erase(subscribeOn queue: DispatchQueue) -> AnyPublisher<Self.Output,Self.Failure> {
        self.subscribe(on: queue).eraseToAnyPublisher()
    }
}

public extension Publisher where Failure == MetaWearError {

    /// Sugar to erase a MetaWearError publisher to an Error publisher
    ///
    func eraseErrorType() -> AnyPublisher<Output,Error> {
        mapError({ $0 as Error }).eraseToAnyPublisher()
    }

}


// MARK: - Internal - Utilities

internal extension MetaWear {

    func BLELazyFuture<O>(closure: @escaping (PromiseClosure<O>) -> Void ) -> MetaPublisher<O> {
        Deferred {
            Future<O, MetaWearError> { promise in
                closure(promise)
            }
        }
        .erase(subscribeOn: self.apiAccessQueue)
    }

    /// Convenience publisher for a one-time read of a board signal **without connection safety**.
    ///
    /// - Parameters:
    ///   - signal: Enum  convenience to access C++ bridge commands
    ///   - type: Type you expect to cast (will crash if incorrect)
    /// - Returns: Pipeline on the BLE queue with the cast data.
    ///
    func ReadNoCheck<T>(_ signal: MWSignal<T>) -> MetaPublisher<T> {

        guard let pointer = signal.from(board) else {
            let error = MetaWearError.operationFailed("Board unavailable when reading \(signal.name) signal.")
            return Fail(outputType: T.self, failure: error)
                .erase(subscribeOn: self.apiAccessQueue)
        }

        return Just(pointer)
            .setFailureType(to: MetaWearError.self)
            .flatMap { $0.readOnce(as: T.self) }
            .mapError { _ in // Replace the generic type failure message
                MetaWearError.operationFailed("Failed reading \(signal.name) signal.")
            }
            .erase(subscribeOn: self.apiAccessQueue)
    }

    /// Convenience publisher for a one-time read of a board signal **without connection safety**.
    ///
    /// - Parameters:
    ///   - signal: Board signal produced by a C++ bridge command like `mbl_mw_settings_get_battery_state_data_signal(board)`
    ///   - type: Type you expect to cast (will crash if incorrect)
    /// - Returns: Pipeline on the BLE queue with the cast data.
    ///
    func ReadNoCheck<T>(signal: OpaquePointer, as type: T.Type) -> MetaPublisher<T> {
        Just(signal)
            .setFailureType(to: MetaWearError.self)
            .flatMap { $0.readOnce(as: T.self) }
            .erase(subscribeOn: self.apiAccessQueue)
    }
}


/// Sugar for Just with an Error output.
func _Just<O>(_ output: O) -> AnyPublisher<O,Error> {
    Just(output).setFailureType(to: Error.self).eraseToAnyPublisher()
}


/// Sugar for Just with a MetaWear output.
func _JustMW(_ bool: Bool) -> AnyPublisher<Bool,MetaWearError> {
    Just(bool).setFailureType(to: MetaWearError.self).eraseToAnyPublisher()
}


/// Simpler semantics when building futures, such as
/// storing a promise-fulfilling closure for a delegate response.
///
internal typealias PromiseClosure<Output> = (Result<Output, MetaWearError>) -> Void
