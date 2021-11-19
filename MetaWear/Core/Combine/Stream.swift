// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// MARK: - Stream

public extension Publisher where Output == MetaWear, Failure == MWError {

    /// Stream time-stamped data from the MetaWear board using a type-safe preset (with optional configuration).
    ///
    /// - Parameters:
    ///   - signal: Type-safe, configurable preset for `MetaWear` board signals
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data.
    ///
    func stream<S: MWStreamable>(_ signal: S) -> MWPublisher<Timestamped<S.DataType>> {
        flatMap { metawear -> MWPublisher<Timestamped<S.DataType>> in
            tryMap { metaWear -> MWDataSignal in
                signal.streamConfigure(board: metaWear.board)

                guard let pointer = try signal.streamSignal(board: metawear.board) else {
                    throw MWError.operationFailed("Signal unavailable for \(signal.name).")
                }
                return pointer
            }
            .stream(signal, board: metawear.board)
            .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// Requires some knowledge of the C++ library and unsafe Swift. Convenience publisher for a streaming board signal.
    ///
    /// - Parameters:
    ///   - signal: A configured board signal produced by a C++ bridge command like `mbl_mw_acc_bosch_get_acceleration_data_signal(board)` after any configuration commmands
    ///   - type: Type you expect to cast (will crash if incorrect)
    ///   - start: Block called after `mbl_mw_datasignal_subscribe` (e.g., `        mbl_mw_acc_enable_acceleration_sampling`; `mbl_mw_acc_start`)
    ///   - cleanup: Block called before `mbl_mw_datasignal_unsubscribe` when the pipeline is cancelled or completed (e.g., `mbl_mw_acc_stop`; `mbl_mw_acc_disable_acceleration_sampling`)
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data.
    ///
    func stream<T>(signal: OpaquePointer,
                   as type: T.Type,
                   start: (() -> Void)?,
                   cleanup: (() -> Void)?
    ) -> MWPublisher<Timestamped<T>> {

        flatMap { metawear -> MWPublisher<Timestamped<T>> in
            signal
                .stream(as: type, start: start, cleanup: cleanup)
                .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }

    /// "Streams" a read signal preset at a regular interval.
    /// - Returns: Time-stamped sensor data
    ///
    func stream<P: MWPollable>(_ pollable: P) -> MWPublisher<Timestamped<P.DataType>> {
        _setupPollableAndTimer(pollable)
            ._setupPollableEvent()
            .flatMap { metawear, sensor, timer -> MWPublisher<Timestamped<P.DataType>> in

                let data = _datasignal_subscribe(sensor)

                // Stream - Stop
                let stop = {
                    mbl_mw_timer_stop(timer)
                    mbl_mw_timer_remove(timer)
                    mbl_mw_datasignal_unsubscribe(sensor)
                }

                // Stream - Start
                mbl_mw_timer_start(timer)

                return data
                    .map(pollable.convertRawToSwift)
                    .handleEvents(receiveCompletion: { _ in stop() }, receiveCancel: stop)
                    .erase(subscribeOn: metawear.apiAccessQueue)
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Data Signal

public extension Publisher where Output == MWDataSignal {

    /// When receiving a configured data signal, start streaming the signal.
    ///
    func stream<S: MWStreamable>(_ streamable: S, board: MWBoard) -> AnyPublisher<Timestamped<S.DataType>, MWError> {
        mapToMetaWearError()
            .flatMap { dataSignal -> AnyPublisher<Timestamped<S.DataType>, MWError> in
                dataSignal.stream(streamable, board: board)
            }
            .eraseToAnyPublisher()
    }

    /// When receiving a configured data signal, start streaming the signal.
    ///
    /// - Parameters:
    ///   - type: Type you expect to cast (will crash if incorrect)
    ///   - start: Block called after `mbl_mw_datasignal_subscribe` (e.g., `mbl_mw_acc_enable_acceleration_sampling`; `mbl_mw_acc_start`)
    ///   - onTerminate: Block called before `mbl_mw_datasignal_unsubscribe` when the pipeline is cancelled or completed (e.g., `mbl_mw_acc_stop`; `mbl_mw_acc_disable_acceleration_sampling`)
    ///
    func stream<T>(as: T.Type,
                   start: (() -> Void)?,
                   cleanup: (() -> Void)?
    ) -> AnyPublisher<Timestamped<T>, MWError> {

        mapToMetaWearError()
            .flatMap { dataSignal -> AnyPublisher<Timestamped<T>, MWError> in
                dataSignal.stream(as: T.self, start: start, cleanup: cleanup)
            }
            .eraseToAnyPublisher()
    }

}

public extension MWDataSignal {

    /// When pointing to a data signal, start streaming the signal.
    ///
    func stream<S: MWStreamable>(_ streamable: S, board: MWBoard) -> AnyPublisher<Timestamped<S.DataType>, MWError> {
        _stream(
            start: { streamable.streamStart(board: board) },
            cleanup: { streamable.streamCleanup(board: board) }
        )
            .mapError { _ in // Replace a generic stream error
                MWError.operationFailed("Could not stream \(S.DataType.self)")
            }
            .map(streamable.convertRawToSwift)
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
    ///   - start: Block called after `mbl_mw_datasignal_subscribe` (e.g., `mbl_mw_acc_enable_acceleration_sampling`; `mbl_mw_acc_start`)
    ///   - onTerminate: Block called before `mbl_mw_datasignal_unsubscribe` when the pipeline is cancelled or completed (e.g., `mbl_mw_acc_stop`; `mbl_mw_acc_disable_acceleration_sampling`)
    ///
    func stream<T>(as:      T.Type,
                   start:   (() -> Void)?,
                   cleanup: (() -> Void)?
    ) -> AnyPublisher<Timestamped<T>, MWError> {
        _stream(start: start, cleanup: cleanup)
            .mapError { _ in // Replace a generic stream error
                MWError.operationFailed("Could not stream \(T.self)")
            }
            .map { ($0.timestamp, $0.valueAs() as T) }
            .eraseToAnyPublisher()
    }

    private func _stream(start:   (() -> Void)?,
                         cleanup: (() -> Void)?
    ) -> AnyPublisher<MWData, MWError> {

        let subject = _datasignal_subscribe(self)
        start?()

        return subject
            .handleEvents(receiveCompletion: { completion in
                cleanup?()
                mbl_mw_datasignal_unsubscribe(self)
            }, receiveCancel: {
                cleanup?()
                mbl_mw_datasignal_unsubscribe(self)
                subject.send(completion: .finished)
            })
            .eraseToAnyPublisher()
    }
}

// MARK: - Internal Pollable Helpers

internal extension Publisher where Output == MetaWear, Failure == MWError {

    func _setupPollableAndTimer<P: MWPollable>(_ pollable: P) -> MWPublisher<(device: MetaWear, sensor: OpaquePointer, timer: OpaquePointer)> {

        // Configure module sensor
        handleEvents(receiveOutput: { pollable.pollConfigure(board: $0.board) })

        // Get module sensor signal
            .tryMap { metawear -> (MetaWear, OpaquePointer) in
                guard let moduleSignal = try pollable.pollSensorSignal(board: metawear.board)
                else { throw MWError.operationFailed("Could not create \(pollable.name)") }
                return (metawear, moduleSignal)
            }
            .mapToMetaWearError()

            // Get configured timer signal
            .zip(createTimer(period: pollable.pollingPeriod))
            .map { ($0.0, $0.1, $1) }
            .eraseToAnyPublisher()
    }
}

internal extension Publisher where Output == (device: MetaWear, sensor: OpaquePointer, timer: OpaquePointer), Failure == MWError {

    /// Stream - Record a repeating "read" event
    func _setupPollableEvent() -> MWPublisher<Output> {
        flatMap { metawear, sensor, timer -> MWPublisher<Output> in

            let status = _MWStatusSubject()
            mbl_mw_event_record_commands(timer)
            mbl_mw_datasignal_read(sensor)
            mbl_mw_event_end_record(timer, bridge(obj: status)) { context, event, status in
                let _subject: _MWStatusSubject = bridge(ptr: context!)
                MWStatusCode.send(to: _subject, cpp: status, completeOnOK: false)
            }
            return status
                .map { _ in (metawear, sensor, timer) }
                .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }
}
