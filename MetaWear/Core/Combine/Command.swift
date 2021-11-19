// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

public extension Publisher where Output == MetaWear, Failure == MWError {

    /// Completes upon issuing the command to the MetaWear (on the `apiAccessQueue`)
    /// - Returns: MetaWear
    ///
    func command<C: MWCommand>(_ command: C) -> MWPublisher<MetaWear> {
        flatMap { metaWear -> MWPublisher<MetaWear> in
            Just(metaWear)
                .setFailureType(to: MWError.self)
                .handleEvents(receiveOutput: { metaWear in
                    command.command(board: metaWear.board)
                })
                .erase(subscribeOn: metaWear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }
}

public extension MWBoard {

    /// When pointing to a board, issues a preset command.
    ///
    func command<C: MWCommand>(_ command: C) -> AnyPublisher<MWBoard,Never> {
        Just(self)
            .setFailureType(to: Never.self)
            .handleEvents(receiveOutput: { board in
                command.command(board: self)
            })
            .eraseToAnyPublisher()
    }
}
