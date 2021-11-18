////Copyright

import Foundation
import MetaWearCpp
import Combine

// MblMwDataSignal

public extension Publisher where Output == MWDataSignal {

    /// When receiving a data signal, start streaming the signal.
    ///
    func stream<S: MWStreamable>(_ streamable: S, board: MWBoard) -> AnyPublisher<Timestamped<S.DataType>, MetaWearError> {
        mapToMetaWearError()
            .flatMap { dataSignal -> AnyPublisher<Timestamped<S.DataType>, MetaWearError> in
                dataSignal.stream(streamable, board: board)
            }
            .eraseToAnyPublisher()
    }

    /// When receiving a data signal, start streaming the signal.
    ///
    /// - Parameters:
    ///   - type: Type you expect to cast (will crash if incorrect)
    ///   - configure: Block called to configure a stream (optional) before `mbl_mw_datasignal_subscribe` (e.g., `mbl_mw_acc_set_odr`; `mbl_mw_acc_bosch_write_acceleration_config`)
    ///   - start: Block called after `mbl_mw_datasignal_subscribe` (e.g., `mbl_mw_acc_enable_acceleration_sampling`; `mbl_mw_acc_start`)
    ///   - onTerminate: Block called before `mbl_mw_datasignal_unsubscribe` when the pipeline is cancelled or completed (e.g., `mbl_mw_acc_stop`; `mbl_mw_acc_disable_acceleration_sampling`)
    ///
    func stream<T>(as: T.Type,
                   configure: EscapingHandler,
                   start: EscapingHandler,
                   onTerminate: EscapingHandler
    ) -> AnyPublisher<Timestamped<T>, MetaWearError> {
        
        mapToMetaWearError()
            .flatMap { dataSignal -> AnyPublisher<Timestamped<T>, MetaWearError> in
                dataSignal
                    .stream(as: T.self,
                            configure: configure,
                            start: start,
                            cleanup: onTerminate)
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

    /// When pointing to a data signal, start streaming the signal.
    ///
    func stream<S: MWStreamable>(_ streamable: S, board: MWBoard) -> AnyPublisher<Timestamped<S.DataType>, MetaWearError> {
        _stream(
            configure: { streamable.streamStart(board: board) },
            start: { streamable.streamStart(board: board) },
            cleanup: { streamable.streamStart(board: board) }
        )
            .mapError { _ in // Replace a generic stream error
                MetaWearError.operationFailed("Could not stream \(S.DataType.self)")
            }
            .map(streamable.convert(data:))
            .eraseToAnyPublisher()
    }

    /// When pointing to a data signal, start streaming the signal.
    ///
    /// Performs:
    ///   - Handler execution
    ///   - `mbl_mw_datasignal_subscribe`
    ///   - On cancel: `mbl_mw_datasignal_unsubscribe`
    ///
    /// - Parameters:
    ///   - configure: Block called to configure a stream (optional) before `mbl_mw_datasignal_subscribe` (e.g., `mbl_mw_acc_set_odr`; `mbl_mw_acc_bosch_write_acceleration_config`)
    ///   - start: Block called after `mbl_mw_datasignal_subscribe` (e.g., `mbl_mw_acc_enable_acceleration_sampling`; `mbl_mw_acc_start`)
    ///   - onTerminate: Block called before `mbl_mw_datasignal_unsubscribe` when the pipeline is cancelled or completed (e.g., `mbl_mw_acc_stop`; `mbl_mw_acc_disable_acceleration_sampling`)
    ///
    func stream<T>(as: T.Type,
                   configure: EscapingHandler,
                   start:     EscapingHandler,
                   cleanup:   EscapingHandler
    ) -> AnyPublisher<Timestamped<T>, MetaWearError> {
        _stream(configure: configure, start: start, cleanup: cleanup)
            .mapError { _ in // Replace a generic stream error
                MetaWearError.operationFailed("Could not stream \(T.self)")
            }
            .map { ($0.timestamp, $0.valueAs() as T) }
            .eraseToAnyPublisher()
    }

    private func _stream(configure: EscapingHandler,
                         start:     EscapingHandler,
                         cleanup:   EscapingHandler
    ) -> AnyPublisher<MWData, MetaWearError> {

        let subject = PassthroughSubject<MWData, MetaWearError>()

        configure?()

        mbl_mw_datasignal_subscribe(self, bridgeRetained(obj: subject)) { (context, dataPtr) in
            let _subject: PassthroughSubject<MWData, MetaWearError> = bridgeTransfer(ptr: context!)

            if let dataPtr = dataPtr {
                _subject.send(dataPtr.pointee.copy())
            } else {
                _subject.send(completion: .failure(.operationFailed("Could not subscribe")))
            }
        }

        start?()

        return subject
            .handleEvents(receiveCompletion: { completion in
                cleanup?()
                mbl_mw_datasignal_unsubscribe(self)
            }, receiveCancel: {
                cleanup?()
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

    /// When pointing to a data signal, perform a one-time read.
    ///
    func read<R: MWReadable>(_ readable: R) -> AnyPublisher<Timestamped<R.DataType>, MetaWearError> {
        _read()
            .map(readable.convert(data:))
            .mapError { _ in // Replace a generic read error (C function pointer cannot form w/ generic)
                MetaWearError.operationFailed("Could not read \(R.DataType.self)")
            }
            .eraseToAnyPublisher()
    }

    /// When pointing to a data signal, perform a one-time read.
    ///
    /// Performs:
    ///   - `mbl_mw_datasignal_subscribe`
    ///   - `dataPtr.pointee.copy` -> ensures lifetime extends beyond closure
    ///   - `.valueAs` casts from `MetaWearData`
    ///   - `mbl_mw_datasignal_read`
    ///   - `mbl_mw_datasignal_unsubscribe` (on cancel or completion)
    ///
    func read<T>(as: T.Type) -> AnyPublisher<Timestamped<T>, MetaWearError> {
        _read()
            .map { ($0.timestamp, $0.valueAs() as T) }
            .mapError { _ in // Replace a generic read error (C function pointer cannot form w/ generic)
                MetaWearError.operationFailed("Could not read \(T.self)")
            }
            .eraseToAnyPublisher()
    }

    private func _read() -> AnyPublisher<MWData, MetaWearError> {

        assert(mbl_mw_datasignal_is_readable(self) != 0)
        let subject = PassthroughSubject<MWData, MetaWearError>()

        mbl_mw_datasignal_subscribe(self, bridgeRetained(obj: subject)) { (context, dataPtr) in
            let _subject: PassthroughSubject<MWData, MetaWearError> = bridgeTransfer(ptr: context!)

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
