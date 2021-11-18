//  © 2021 Ryan Ferrell. github.com/importRyan


import Foundation

// MARK: - Internal (Default Implementations)

public extension MWDataConvertible {
    func convert(data: MWData) -> Timestamped<DataType> {
        (time: data.timestamp, data.valueAs() as DataType)
    }
    var name: String { "\(Self.self)" }
}

public extension MWLoggable where Self: MWStreamable {

    func loggerSignal(board: MWBoard) throws -> MWDataSignal? {
        try self.streamSignal(board: board)
    }

    func loggerConfigure(board: MWBoard) {
        self.streamCleanup(board: board)
    }

    func loggerPrepare(board: MWBoard) {
        self.streamStart(board: board)
    }

    func loggerCleanup(board: MWBoard) {
        self.streamCleanup(board: board)
    }
}
