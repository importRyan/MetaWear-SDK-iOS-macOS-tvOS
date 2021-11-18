////Copyright

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals



// MARK: - Discoverable Presets



// MARK: - C++ Constants

public enum MWHumidityOversampling: Int, CaseIterable, IdentifiableByRawValue {
    case x1 = 1
    case x2 = 2
    case x4 = 4
    case x8 = 8
    case x16 = 16

    public var cppEnumValue: MblMwHumidityBme280Oversampling {
        switch self {
            case .x1: return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_1X
            case .x2: return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_2X
            case .x4: return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_4X
            case .x8: return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_8X
            case .x16: return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_16X
        }
    }
}
