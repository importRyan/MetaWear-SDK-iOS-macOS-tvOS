////Copyright

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

public struct MWGyroscope {

}

// MARK: - Discoverable Presets



// MARK: - C++ Constants

public extension MWGyroscope {

    enum GraphRange: Int, CaseIterable, IdentifiableByRawValue {
        case dps125  = 125
        case dps250  = 250
        case dps500  = 500
        case dps1000 = 1000
        case dps2000 = 2000

        public var fullScale: Int {
            switch self {
                case .dps125: return 1
                case .dps250: return 2
                case .dps500: return 4
                case .dps1000: return 8
                case .dps2000: return 16
            }
        }

        /// Raw Cpp constant
        public var cppEnumValue: MblMwGyroBoschRange {
            switch self {
                case .dps125: return MBL_MW_GYRO_BOSCH_RANGE_125dps
                case .dps250: return MBL_MW_GYRO_BOSCH_RANGE_250dps
                case .dps500: return MBL_MW_GYRO_BOSCH_RANGE_500dps
                case .dps1000: return MBL_MW_GYRO_BOSCH_RANGE_1000dps
                case .dps2000: return MBL_MW_GYRO_BOSCH_RANGE_2000dps
            }
        }
    }

    enum Frequency: Int, CaseIterable, IdentifiableByRawValue {
        case hz1600 = 1600
        case hz800  = 800
        case hz400  = 400
        case hs200  = 200
        case hz100  = 100
        case hz50   = 50
        case hz25   = 25

        /// Raw Cpp constant
        public var cppEnumValue: MblMwGyroBoschOdr {
            switch self {
                case .hz1600: return MBL_MW_GYRO_BOSCH_ODR_1600Hz
                case .hz800: return MBL_MW_GYRO_BOSCH_ODR_800Hz
                case .hz400: return MBL_MW_GYRO_BOSCH_ODR_400Hz
                case .hs200: return MBL_MW_GYRO_BOSCH_ODR_200Hz
                case .hz100: return MBL_MW_GYRO_BOSCH_ODR_100Hz
                case .hz50: return MBL_MW_GYRO_BOSCH_ODR_50Hz
                case .hz25: return MBL_MW_GYRO_BOSCH_ODR_25Hz
            }
        }
    }
}
