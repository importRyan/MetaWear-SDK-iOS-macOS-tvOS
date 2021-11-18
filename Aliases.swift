//  © 2021 Ryan Ferrell. github.com/importRyan

import Foundation
import Combine
import MetaWearCpp

//func stream<S: MWStreamable>(_ signal: S) -> Timestamped<S.DataType> {
//    signal.convert(data: .init())
//}

// MARK: - Combine Aliases

/// This publisher subscribes and returns on
/// its parent scanner's Bluetooth queue to
/// ensure safe usage of the MetaWear C++ library.
///
/// To update your UI, use
/// `.receive(on: DispatchQueue.main)`.
///
public typealias MetaPublisher<Output>  = AnyPublisher<Output, MetaWearError>


// MARK: - Signal Aliases

/// References the MetaWear's board
public typealias MWBoard                = OpaquePointer

/// References a signal from a board
/// module (e.g., accelerometer) for
/// streaming, logging, or reading
/// `MblMwDataSignal`
public typealias MWDataSignal           = OpaquePointer

/// References a board or data signal
/// (e.g., for a data processor)
public typealias MWBoardOrDataSignal    = OpaquePointer

/// References a data processor output,
/// which can be read or fed back into
/// other data processors
public typealias MWDataProcessorSignal  = OpaquePointer


// MARK: - Other Aliases

public typealias Timestamped<V>         = (time: Date, value: V)

public typealias EscapingHandler        = (() -> Void)?
