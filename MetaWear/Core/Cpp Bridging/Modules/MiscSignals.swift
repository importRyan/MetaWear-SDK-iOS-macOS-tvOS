////Copyright

import Foundation
import MetaWearCpp
import Combine

// MARK: - Battery Life

public struct MWBatteryLevel: MWDataConvertible, MWReadable {
    public typealias DataType = Int8
    public func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_settings_get_battery_state_data_signal(board)
    }
}

extension MWReadable where Self == MWBatteryLevel {
    static var batteryLevel: Self { Self() }
}


// MARK: - MAC Address

public struct MWMACAddress: MWDataConvertible, MWReadable {
    public typealias DataType = String
    public func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_settings_get_mac_data_signal(board)
    }
}

extension MWReadable where Self == MWMACAddress {
    static var macAddress: Self { Self() }
}

