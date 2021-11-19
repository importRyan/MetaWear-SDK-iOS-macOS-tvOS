// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp


public extension Publisher where Output == MetaWear {

    /// Creates a timer on the MetaWear.
    ///
    func createTimer(period: UInt32,
                     repetitions: UInt16 = .max,
                     immediateFire: Bool = false
    ) -> MWPublisher<OpaquePointer> {
        mapToMetaWearError()
        .flatMap { device -> MWPublisher<OpaquePointer> in
            return device.board
                .createTimer(period: period, repetitions: repetitions, immediateFire: immediateFire)
                .erase(subscribeOn: device.apiAccessQueue)
        }
        .eraseToAnyPublisher()
    }
}


public extension MWBoard {

    /// When pointing to a board, creates a timer. Combine interface to `mbl_mw_timer_create`.
    ///
    func createTimer(period: UInt32,
                     repetitions: UInt16 = .max,
                     immediateFire: Bool = false
    ) -> PassthroughSubject<OpaquePointer, MWError> {

        let subject = PassthroughSubject<OpaquePointer,MWError>()

        mbl_mw_timer_create(self, period, repetitions, immediateFire ? 0 : 1, bridge(obj: subject)) { (context, timer) in
            let _subject: PassthroughSubject<OpaquePointer, MWError> = bridge(ptr: context!)

            if let timer = timer {
                _subject.send(timer)
            } else {
                _subject.send(completion: .failure(.operationFailed("Could not create timer")))
            }
        }

        return subject
    }
}
