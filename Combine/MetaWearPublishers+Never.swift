//  © 2021 Ryan Ferrell. github.com/importRyan


import Foundation
import Combine

// MARK: - Public API For Failure Type == Never
// (These alias Failure == MetaWearError operators)

public extension Publisher where Output == MetaWear, Failure == Never {

    func readOnce<T>(signal: MWSignal<T>) -> MetaPublisher<T> {
        setFailureType(to: MetaWearError.self)
            .readOnce(signal: signal)
    }

    func readOnce<T>(signal: OpaquePointer, as type: T.Type) -> MetaPublisher<T> {
        setFailureType(to: MetaWearError.self)
            .readOnce(signal: signal, as: type.self)
    }

    func stream<T>(_ signal: MWSignal<T>,
                   start: EscapingHandler,
                   onTerminate: EscapingHandler
    ) -> MetaPublisher<Timestamped<T>> {
        setFailureType(to: MetaWearError.self)
            .stream(signal, start: start, onTerminate: onTerminate)
    }

    func stream<T>(signal: OpaquePointer,
                   as type: T.Type,
                   start: EscapingHandler,
                   onTerminate: EscapingHandler
    ) -> MetaPublisher<Timestamped<T>> {
        setFailureType(to: MetaWearError.self)
            .stream(signal: signal, as: type, start: start, onTerminate: onTerminate)
    }
}

