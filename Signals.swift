//  © 2021 Ryan Ferrell. github.com/importRyan


import Foundation
import MetaWearCpp

// These contracts interact with
// MetaWear modules with type safety and
// code completion.

// You won't use the protocol's methods,
// most likely. Just know the types,
// which define a broad behavior, like
// "readable once" or "loggable".

// Each module differs in capabilities,
// customizations, and the C++ methods
// required to operate them. Some also
// have multiple models with different
// capabilities. Objects implementing
// these protocols abstract that away
// from end users — and provide a
// reference when you need to write
// your own abstractions.


// MARK: - Log

/// This module supports logging data to
/// onboard storage.
public protocol MWLoggable: MWDataConvertible {

    /// The MetaWear device's identifier
    /// for the logger.
    var loggerName: MWLoggerName { get }
    /// Obtains a reference to the
    /// module's loggable signal.
    func loggerSignal(board: MWBoard) throws -> MWDataSignal?
    /// Commands to customize the logger
    func loggerConfigure(board: MWBoard)
    /// Commands before starting the logger
    func loggerPrepare(board: MWBoard)
    /// Commands to end the logger
    func loggerCleanup(board: MWBoard)
}


// MARK: - Stream

/// This module supports streaming data
/// at up to 100 Hz.
public protocol MWStreamable: MWDataConvertible {

    /// Obtains a reference to the module's
    /// streamable signal.
    func streamSignal(board: MWBoard) throws -> MWDataSignal?
    // Commands to customize the stream
    func streamConfigure(board: MWBoard)
    // Commands before starting the stream
    func streamStart(board: MWBoard)
    // Commands to end the stream
    func streamCleanup(board: MWBoard)
}

/// This module's data can be "streamed"
/// by polling at a reasonable interval.
public protocol MWPollable: MWReadable {

    /// Provides publisher at the right tempo.
    func pollingTimer() -> Timer.TimerPublisher
}


// MARK: - Read Once

/// For signals that can only be read once
public protocol MWReadable: MWDataConvertible {
    func readableSignal(board: MWBoard) throws -> MWDataSignal?
}


// MARK: - Type Safe Data Conversions

/// Has a defined conversion from
/// a `MblMwData` C++ struct into a
/// defined Swift value type whose lifetime
/// is not confined to the C++ closure.
public protocol MWDataConvertible {

    /// Final converted Swift value type
    associatedtype DataType

    /// Converts `MblMwData` to a concretely
    /// typed timestamped tuple, possibly
    /// through an intermediary value type.
    func convert(data: MWData) -> Timestamped<DataType>

    /// Name for error messages
    var name: String { get }
}
