////Copyright

import Foundation
import Combine
import MetaWearCpp


// These are code completion-friendly presets
// for obtaining a data signal from a MetaWear
// without directly calling C++ functions or
// casting incoming data as the correct type.
//
// Try them in functions like`.readOnceIfSetup`.

extension MWSignal where DataType == String {

    /// Values:
    static let macAddress = MWSignal("MAC Address", mbl_mw_settings_get_mac_data_signal)

}

extension MWSignal where DataType == Int8 {

    /// Values: 0 to 100
    static let batteryPercentage = MWSignal("Battery Level", mbl_mw_settings_get_battery_state_data_signal)

}

// MARK: - Internal

/// Defines a signal `OpaquePointer` generated from a MetaWear board.
/// Use presets above in functions like `readOnceIfSetup`.
///
public struct MWSignal<DataType> {

    /// Used for error messages
    public let name: String

    /// Cpp function to obtain the signal from the provided `MetaWear` board
    public let `from`: (OpaquePointer) -> OpaquePointer?

    internal init(_ name: String, _ cpp: @escaping (OpaquePointer) -> OpaquePointer?) {
        self.name = name
        self.`from` = cpp
    }
}
