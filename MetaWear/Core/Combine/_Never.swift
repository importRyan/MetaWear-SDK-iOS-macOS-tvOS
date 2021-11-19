// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine

// MARK: - Public API For Failure Type == Never
// (These alias Failure == MetaWearError operators)

public extension Publisher where Output == MetaWear, Failure == Never {

    /// Performs a one-time read of a board signal, handling C++ library calls, pointer bridging, and returned data type casting.
    ///
    /// - Parameters:
    ///   - signal: Type-safe preset for `MetaWear` board signals
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected.
    ///
    func read<R: MWReadable>(signal: R) -> MWPublisher<Timestamped<R.DataType>> {
        setFailureType(to: MWError.self)
            .read(signal: signal)
    }

    /// Performs a one-time read of a board signal, handling pointer bridging, and casting to the provided type.
    ///
    /// - Parameters:
    ///   - signal: Board signal produced by a C++ bridge command like `mbl_mw_settings_get_battery_state_data_signal(board)`
    ///   - type: Type you expect to cast (will crash if incorrect)
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data. Fails if not connected.
    ///
    func read<T>(signal: OpaquePointer, as type: T.Type) -> MWPublisher<Timestamped<T>> {
        setFailureType(to: MWError.self)
            .read(signal: signal, as: type.self)
    }

    /// Stream time-stamped data from the MetaWear board using a type-safe preset (with optional configuration).
    ///
    /// - Parameters:
    ///   - signal: Type-safe, configurable preset for `MetaWear` board signals
    ///
    /// - Returns: Pipeline on the BLE queue with the cast data.
    ///
    func stream<S: MWStreamable>(_ signal: S) -> MWPublisher<Timestamped<S.DataType>> {
        setFailureType(to: MWError.self)
            .stream(signal)
    }

    /// Requires some knowledge of the C++ library and unsafe Swift. Convenience publisher for a streaming board signal.
    ///
    /// - Parameters:
    ///   - signal: A configured board signal produced by a C++ bridge command like `mbl_mw_acc_bosch_get_acceleration_data_signal(board)`
    ///   - type: Type you expect to cast (will crash if incorrect)
    ///   - configure: Block called to configure a stream (optional) before `mbl_mw_datasignal_subscribe` (e.g., `mbl_mw_acc_set_odr`; `mbl_mw_acc_bosch_write_acceleration_config`)
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
        setFailureType(to: MWError.self)
            .stream(signal: signal, as: type, start: start, cleanup: cleanup)
    }

    /// Completes upon issuing the command to the MetaWear (on the `apiAccessQueue`)
    /// - Returns: MetaWear
    ///
    func command<C: MWCommand>(_ command: C) -> MWPublisher<MetaWear> {
        setFailureType(to: MWError.self)
            .command(command)
    }
}

