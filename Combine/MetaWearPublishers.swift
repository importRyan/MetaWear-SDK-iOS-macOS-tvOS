////Copyright

import Foundation
import Combine

/// A type-erased publisher that subscribes and returns on its parent's BLE queue. For UI updates, add `.receive(on: DispatchQueue.main)`.
///
public typealias MetaPublisher<Output> = AnyPublisher<Output, MetaWearError>

public extension Publisher where Output == MetaWear, Failure == MetaWearError {

    /// Performs a one-time read of a board signal, handling C++ library calls, pointer bridging, and returned data type casting.
    ///
    /// - Parameters:
    ///   - signal: Type-safe preset for `MetaWear` board signals
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected.
    ///
    func readOnce<T>(signal: MWSignal<T>) -> MetaPublisher<T> {
        flatMap { metawear -> MetaPublisher<T> in

            guard let pointer = signal.from(metawear.board) else {
                return Fail(
                    outputType: T.self,
                    failure: MetaWearError.operationFailed("Board unavailable for \(signal.name).")
                ).eraseToAnyPublisher()
            }

            return pointer.readOnce(as: T.self)
                .mapError { _ in // Replace the generic type failure message
                    MetaWearError.operationFailed("Failed reading \(signal.name).")
                }
                .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// Performs a one-time read of a board signal, handling pointer bridging, and casting to the provided type.
    ///
    /// - Parameters:
    ///   - signal: Board signal produced by a C++ bridge command like `mbl_mw_settings_get_battery_state_data_signal(board)`
    ///   - type: Type you expect to cast (will crash if incorrect)
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected.
    ///
    func readOnce<T>(signal: OpaquePointer, as type: T.Type) -> MetaPublisher<T> {
        flatMap { metawear in
            metawear.board
                .readOnce(as: T.self)
                .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// Convenience publisher for a streaming board signal.
    ///
    /// - Parameters:
    ///   - signal: Type-safe preset for `MetaWear` board signals
    ///   - type: Type you expect to cast (will crash if incorrect)
    /// - Returns: Pipeline on the BLE queue with the cast data.
    ///
    func stream<T>(_ signal: MWSignal<T>,
                   start: EscapingHandler,
                   onTerminate: EscapingHandler
    ) -> MetaPublisher<Timestamped<T>> {

        flatMap { metawear -> MetaPublisher<Timestamped<T>> in
            tryMap { metaWear -> MWDataSignal in
                guard let pointer = signal.from(metaWear.board) else {
                    throw MetaWearError.operationFailed("Board unavailable for \(signal.name).")
                }
                return pointer
            }
            .stream(as: T.self, start: start, onTerminate: onTerminate)
            .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// Convenience publisher for a streaming board signal.
    ///
    /// - Parameters:
    ///   - signal: Board signal produced by a C++ bridge command like `mbl_mw_acc_bosch_get_acceleration_data_signal(board)`
    ///   - type: Type you expect to cast (will crash if incorrect)
    /// - Returns: Pipeline on the BLE queue with the cast data.
    ///
    func stream<T>(signal: OpaquePointer,
                   as type: T.Type,
                   start: EscapingHandler,
                   onTerminate: EscapingHandler
    ) -> MetaPublisher<Timestamped<T>> {

        flatMap { metawear -> MetaPublisher<Timestamped<T>> in
            signal
                .stream(as: type, onTerminate: onTerminate)
                .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Any Failure Type

public extension Publisher where Output == MetaWear {

    func collectAnonymousLoggerSignals() -> MetaPublisher<[OpaquePointer]> {
        mapToMetaWearError()
        .flatMap { device -> MetaPublisher<[OpaquePointer]> in
            return device.board
                .collectAnonymousLoggerSignals()
                .erase(subscribeOn: device.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// Creates a timer on the MetaWear.
    ///
    func createTimer(period: UInt32,
                     repetitions: UInt16 = 0xFFFF,
                     immediateFire: Bool = false) -> MetaPublisher<OpaquePointer> {
        mapToMetaWearError()
        .flatMap { device -> MetaPublisher<OpaquePointer> in
            return device.board
                .createTimer(period: period, repetitions: repetitions, immediateFire: immediateFire)
                .erase(subscribeOn: device.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// Ends macro recordings.
    ///
    func macroEndRecording() -> MetaPublisher<Int32> {
        mapToMetaWearError()
        .flatMap { device -> MetaPublisher<Int32> in
            return device.board
                .macroEndRecording()
                .erase(subscribeOn: device.apiAccessQueue)
        }
        .eraseToAnyPublisher()
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
