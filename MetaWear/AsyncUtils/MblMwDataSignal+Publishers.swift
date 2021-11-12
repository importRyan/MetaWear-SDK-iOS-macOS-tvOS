////Copyright

import Foundation
import MetaWearCpp
import Combine


// MARK: - Log Signal

extension OpaquePointer {

    /// Combine interface for `mbl_mw_datasignal_log`
    /// Log signal
    ///
    public func datasignalLog() -> AnyPublisher<OpaquePointer, MetaWearError> {

        let subject = PassthroughSubject<OpaquePointer,MetaWearError>()
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


// MARK: - Read Signal

extension OpaquePointer {

    /// Combine interface for a one-time read of a MetaWear data signal. Performs:
    /// `mbl_mw_datasignal_subscribe`
    /// `dataPtr.pointee.copy`
    /// `.valueAs`
    /// `mbl_mw_datasignal_read`
    /// `mbl_mw_datasignal_unsubscribe`
    ///
    public func readOnce<T>(as: T.Type) -> AnyPublisher<T, MetaWearError> {
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
    /// `mbl_mw_datasignal_unsubscribe`
    ///
    public func readOnceTimestamped<T>(as: T.Type) -> AnyPublisher<(timestamp: Date, value: T), MetaWearError> {
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
    /// `mbl_mw_datasignal_unsubscribe`
    ///
    public func readOnce() -> AnyPublisher<MetaWearData, MetaWearError> {

        assert(mbl_mw_datasignal_is_readable(self) != 0)
        let subject = PassthroughSubject<MetaWearData, MetaWearError>()

        mbl_mw_datasignal_subscribe(self, bridgeRetained(obj: subject)) { (context, dataPtr) in
            let _subject: PassthroughSubject<MetaWearData, MetaWearError> = bridgeTransfer(ptr: context!)

            if let dataPtr = dataPtr {
                _subject.send(dataPtr.pointee.copy())
                _subject.send(completion: .finished)
            } else {
                _subject.send(completion: .failure(.operationFailed("could not subscribe")))
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
