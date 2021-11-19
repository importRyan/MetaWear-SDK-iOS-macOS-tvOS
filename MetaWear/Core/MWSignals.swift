// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

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
    var loggerName: MWLogger { get }
    /// Obtains a reference to the
    /// module's loggable signal.
    func loggerDataSignal(board: MWBoard) throws -> MWDataSignal?
    /// Commands to customize the logger
    func loggerConfigure(board: MWBoard)
    /// Commands to start the signal to be logged
    func loggerStart(board: MWBoard)
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

    /// Rate at which the MetaWear board should be queried for values
    var pollingRate: TimeInterval { get }

    // Commands to customize the "stream"
    func pollConfigure(board: MWBoard)
    /// Obtains a reference to the module's
    /// "streamable" signal.
    func pollSensorSignal(board: MWBoard) throws -> MWDataSignal?
}


// MARK: - Read Once

/// For signals that can only be read once
public protocol MWReadable: MWDataConvertible {
    func readableSignal(board: MWBoard) throws -> MWDataSignal?

    func readConfigure(board: MWBoard)

    func readCleanup(board: MWBoard)
}

// MARK: - Command

public protocol MWCommand {

    func command(board: MWBoard)
}


// MARK: - Internal Defaults (DRY)

public extension MWLoggable where Self: MWStreamable {

    func loggerDataSignal(board: MWBoard) throws -> MWDataSignal? {
        try self.streamSignal(board: board)
    }

    func loggerConfigure(board: MWBoard) {
        self.streamConfigure(board: board)
    }

    func loggerStart(board: MWBoard) {
        self.streamStart(board: board)
    }

    func loggerCleanup(board: MWBoard) {
        self.streamCleanup(board: board)
    }
}

public extension MWPollable {

    func pollConfigure(board: MWBoard) {
        self.readConfigure(board: board)
    }

    func pollSensorSignal(board: MWBoard) throws -> MWDataSignal? {
        try self.readableSignal(board: board)
    }

    var pollingPeriod: UInt32 {
        UInt32(1/pollingRate)
    }
}

/// Raw value: ms
public enum MWPollingFrequency: Int, CaseIterable, IdentifiableByRawValue {
    case hr1
    case m30
    case m10
    case m1
    case s30
    case s10
    case s5
    case s2
    case hz1
    case hz10
    case hz25
    case hz50
    case hz100

    public var ms: Int {
        switch self {
            case .hr1:   return 3_300_000
            case .m30:   return 1_800_000
            case .m10:   return 600_000
            case .m1:    return 60_000
            case .s30:   return 30_000
            case .s10:   return 10_000
            case .s5:    return 5_000
            case .s2:    return 2_000
            case .hz1:   return 1_000
            case .hz10:  return 100
            case .hz25:  return 40
            case .hz50:  return 20
            case .hz100: return 10
        }
    }
}
