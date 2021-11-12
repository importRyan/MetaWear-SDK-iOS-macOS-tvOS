////Copyright

import Foundation
import MetaWearCpp
import Combine

public typealias Timestamped<T> = (timestamp: Date, value: T)
public typealias EscapingHandler = (() -> Void)?
public typealias MWDataSignal = OpaquePointer

public extension Publisher where Output == MWDataSignal {

    func stream<T>(as: T.Type,
                   start: EscapingHandler,
                   onTerminate: EscapingHandler
    ) -> AnyPublisher<Timestamped<T>, MetaWearError> {
        mapToMetaWearError()
            .flatMap { dataSignal -> AnyPublisher<Timestamped<T>, MetaWearError> in
                start?()
                return dataSignal.stream(as: T.self, onTerminate: onTerminate)
            }
            .eraseToAnyPublisher()
    }

    /// When receiving a data signal, starts logging the signal. Combine interface for `mbl_mw_datasignal_log`.
    ///
    func logger() -> AnyPublisher<OpaquePointer, MetaWearError> {
        mapToMetaWearError()
        .flatMap { signal -> AnyPublisher<OpaquePointer, MetaWearError> in
            signal.logger()
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Utilities on an `MWDataSignal` `OpaquePointer`

// MARK: - Stream Signal

public extension MWDataSignal {

    /// When pointing to a data signal, start streaming the signal. Combine interface for `mbl_mw_datasignal_subscribe`
    /// `mbl_mw_datasignal_is_readable`
    /// `mbl_mw_datasignal_subscribe`
    ///  On cancel: `mbl_mw_datasignal_unsubscribe`
    ///
    func stream<T>(as: T.Type, onTerminate: EscapingHandler) -> AnyPublisher<Timestamped<T>, MetaWearError> {
        stream(onTerminate: onTerminate)
            .mapError { _ in // Replace a generic stream error
                MetaWearError.operationFailed("Could not stream \(T.self)")
            }
            .map { ($0.timestamp, $0.valueAs() as T) }
            .eraseToAnyPublisher()
    }

    /// When pointing to a data signal, start streaming the signal. Combine interface for `mbl_mw_datasignal_subscribe`
    /// `mbl_mw_datasignal_is_readable`
    /// `mbl_mw_datasignal_subscribe`
    ///  On cancel: `mbl_mw_datasignal_unsubscribe`
    ///
    func stream(onTerminate: EscapingHandler) -> AnyPublisher<MetaWearData, MetaWearError> {
        assert(mbl_mw_datasignal_is_readable(self) != 0)
        let subject = PassthroughSubject<MetaWearData, MetaWearError>()

        mbl_mw_datasignal_subscribe(self, bridgeRetained(obj: subject)) { (context, dataPtr) in
            let _subject: PassthroughSubject<MetaWearData, MetaWearError> = bridgeTransfer(ptr: context!)

            if let dataPtr = dataPtr {
                _subject.send(dataPtr.pointee.copy())
            } else {
                _subject.send(completion: .failure(.operationFailed("Could not subscribe")))
            }
        }

        return subject
            .handleEvents(receiveCompletion: { completion in
                onTerminate?()
                mbl_mw_datasignal_unsubscribe(self)
            }, receiveCancel: {
                onTerminate?()
                mbl_mw_datasignal_unsubscribe(self)
            })
            .eraseToAnyPublisher()
    }
}

// MARK: - Logger Signal

public extension MWDataSignal {

    /// When pointing to a data signal, start logging the signal, returning a pointer to the logger. Combine interface for `mbl_mw_datasignal_log`
    ///
    func logger() -> AnyPublisher<OpaquePointer, MetaWearError> {

        let subject = PassthroughSubject<OpaquePointer, MetaWearError>()
        mbl_mw_datasignal_log(self, bridgeRetained(obj: subject)) { (context, logger) in
            let _subject: PassthroughSubject<OpaquePointer,MetaWearError> = bridgeTransfer(ptr: context!)

            if let logger = logger {
                _subject.send(logger)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not create log entry")))
            }
        }
        return subject.eraseToAnyPublisher()
    }
}

// MARK: - Read (Log) Signal

public extension MWDataSignal {

    /// Combine interface for a one-time read of a MetaWear data signal. Performs:
    /// `mbl_mw_datasignal_subscribe`
    /// `dataPtr.pointee.copy`
    /// `.valueAs`
    /// `mbl_mw_datasignal_read`
    /// `mbl_mw_datasignal_unsubscribe`  (on cancel or completion)
    ///
    func readOnce<T>(as: T.Type) -> AnyPublisher<T, MetaWearError> {
        readOnce()
            .mapError { _ in // Replace a generic readOnce error
                MetaWearError.operationFailed("Could not read \(T.self)")
            }
            .map { $0.valueAs() as T }
            .eraseToAnyPublisher()
    }

    /// Combine interface for a one-time read of a MetaWear data signal. Performs:
    /// `mbl_mw_datasignal_subscribe`
    /// `dataPtr.pointee.copy`
    /// `.valueAs`
    /// `mbl_mw_datasignal_read`
    /// `mbl_mw_datasignal_unsubscribe` (on cancel or completion)
    ///
    func readOnceTimestamped<T>(as: T.Type) -> AnyPublisher<Timestamped<T>, MetaWearError> {
        readOnce()
            .mapError { _ in // Replace a generic readOnce error
                MetaWearError.operationFailed("Could not read \(T.self)")
            }
            .map { ($0.timestamp, $0.valueAs() as T) }
            .eraseToAnyPublisher()
    }

    /// Combine interface for a one-time read of a MetaWear data signal. Performs:
    /// `mbl_mw_datasignal_subscribe`
    /// `dataPtr.pointee.copy` ->  timestamped raw`MetaWearData`
    /// `mbl_mw_datasignal_read`
    /// `mbl_mw_datasignal_unsubscribe` (on cancel or completion)
    ///
    func readOnce() -> AnyPublisher<MetaWearData, MetaWearError> {
        assert(mbl_mw_datasignal_is_readable(self) != 0)
        let subject = PassthroughSubject<MetaWearData, MetaWearError>()

        mbl_mw_datasignal_subscribe(self, bridgeRetained(obj: subject)) { (context, dataPtr) in
            let _subject: PassthroughSubject<MetaWearData, MetaWearError> = bridgeTransfer(ptr: context!)

            if let dataPtr = dataPtr {
                _subject.send(dataPtr.pointee.copy())
                _subject.send(completion: .finished)
            } else {
                _subject.send(completion: .failure(.operationFailed("Could not subscribe")))
            }
        }

        mbl_mw_datasignal_read(self)

        return subject
            .handleEvents(receiveCompletion: { completion in
                mbl_mw_datasignal_unsubscribe(self)
            }, receiveCancel: {
                mbl_mw_datasignal_unsubscribe(self)
            })
            .eraseToAnyPublisher()
    }

}
