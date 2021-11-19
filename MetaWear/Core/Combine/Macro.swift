// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// MARK: - Macro

public extension Publisher where Output == MetaWear, Failure == MWError {

    /// Records the commands you provide in the closure. A macro can be executed on each reboot or by an explicit command that references the identifier returned by this function.
    ///
    /// - Parameters:
    ///   - executeOnBoot: Execute this macro eagerly on reboot or when commanded
    ///   - actions: Actions that form the macro
    /// - Returns: An integer that identifies the recorded macro
    ///
    func macro(executeOnBoot: Bool,
               actions: @escaping (MWPublisher<MetaWear>) -> MWPublisher<MetaWear>
    ) -> MWPublisher<MWMacroIdentifier> {
        flatMap { metawear -> MWPublisher<MWMacroIdentifier> in
                mbl_mw_macro_record(metawear.board, executeOnBoot ? 1 : 0)
                return actions(_JustMW(metawear))
                    .flatMap { mw -> MWPublisher<MWMacroIdentifier> in

                        let subject = PassthroughSubject<MWMacroIdentifier,MWError>()
                        mbl_mw_macro_end_record(mw.board, bridge(obj: subject)) { (context, board, value) in
                            let _subject: PassthroughSubject<MWMacroIdentifier,MWError> = bridge(ptr: context!)
                            _subject.send(MWMacroIdentifier(value))
                            _subject.send(completion: .finished)
                        }
                        return subject.eraseToAnyPublisher()
                    }
                    .erase(subscribeOn: metawear.apiAccessQueue)
            }
            .eraseToAnyPublisher()
    }

    /// Run the desired macro.
    /// - Parameter id: Macro identifier
    /// - Returns: Republishes the current MetaWear
    ///
    func macroExecute(id: MWMacroIdentifier) -> MWPublisher<MetaWear> {
        flatMap { metawear -> MWPublisher<MetaWear> in
            mbl_mw_macro_execute(metawear.board, id)
            return _JustMW(metawear)
                .erase(subscribeOn: metawear.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }
}

public extension Publisher where Output == MetaWear {

    /// Records the commands you provide in the closure. A macro can be executed on each reboot or by an explicit command that references the identifier returned by this function.
    ///
    /// - Parameters:
    ///   - executeOnBoot: Execute this macro eagerly on reboot or when commanded
    ///   - actions: Actions that form the macro
    /// - Returns: An integer that identifies the recorded macro
    ///
    func macro(executeOnBoot: Bool,
               actions: @escaping (MWPublisher<MetaWear>) -> MWPublisher<MetaWear>
    ) -> MWPublisher<MWMacroIdentifier> {
        mapToMetaWearError()
            .macro(executeOnBoot: executeOnBoot, actions: actions)
    }
}

// MARK: - MWBoard

public extension MWBoard {

    /// When pointing to a board, ends macro recordings. Combine wrapper for `mbl_mw_macro_end_record`.
    /// - Returns: Identifier for the recorded macro
    ///
    func macroEndRecording() -> PassthroughSubject<Int32,MWError> {

        let subject = PassthroughSubject<Int32,MWError>()

        mbl_mw_macro_end_record(self, bridge(obj: subject)) { (context, board, value) in
            let _subject: PassthroughSubject<Int32,MWError> = bridge(ptr: context!)
            _subject.send(value)
            _subject.send(completion: .finished)
        }

        return subject
    }

}
