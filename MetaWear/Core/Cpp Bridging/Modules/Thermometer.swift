////Copyright

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

public struct MWThermometer {

}

// MARK: - Discoverable Presets



// MARK: - C++ Constants

public extension MWThermometer {

    enum MWTemperatureSource: String, CaseIterable, IdentifiableByRawValue {
        case onDie
        case external
        case bmp280
        case onboard
        case custom

        public init(cpp: MblMwTemperatureSource) {
            self = Self.allCases.first(where: { $0.cppValue == cpp }) ?? .custom
        }

        public var cppValue: MblMwTemperatureSource? {
            switch self {
                case .onDie: return MBL_MW_TEMPERATURE_SOURCE_NRF_DIE
                case .external: return MBL_MW_TEMPERATURE_SOURCE_EXT_THERM
                case .bmp280: return MBL_MW_TEMPERATURE_SOURCE_BMP280
                case .onboard: return MBL_MW_TEMPERATURE_SOURCE_PRESET_THERM
                case .custom: return nil
            }
        }

        public var displayName: String {
            switch self {
                case .onDie: return "On-Die"
                case .external: return "External"
                case .bmp280: return "BMP280"
                case .onboard: return "Onboard"
                case .custom: return "Custom"
            }
        }
    }
}
