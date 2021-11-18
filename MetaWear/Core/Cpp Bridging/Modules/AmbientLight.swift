////Copyright

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

public struct MWAmbientLight {

}

// MARK: - Discoverable Presets



// MARK: - C++ Constants

public extension MWAmbientLight {

    enum Gain: Int, CaseIterable, IdentifiableByRawValue {
        case gain1  = 1
        case gain2  = 2
        case gain4  = 4
        case gain8  = 8
        case gain48 = 48
        case gain96 = 96

        public var cppEnumValue: MblMwAlsLtr329Gain {
            switch self {
                case .gain1: return MBL_MW_ALS_LTR329_GAIN_1X
                case .gain2: return MBL_MW_ALS_LTR329_GAIN_2X
                case .gain4: return MBL_MW_ALS_LTR329_GAIN_4X
                case .gain8: return MBL_MW_ALS_LTR329_GAIN_8X
                case .gain48: return MBL_MW_ALS_LTR329_GAIN_48X
                case .gain96: return MBL_MW_ALS_LTR329_GAIN_96X
            }
        }

        public var displayName: String { String(rawValue) }
    }

    enum TR329IntegrationTime: Int, CaseIterable, IdentifiableByRawValue {
        case ms50  = 50
        case ms100 = 100
        case ms150 = 150
        case ms200 = 200
        case ms250 = 250
        case ms300 = 300
        case ms350 = 350
        case ms400 = 400

        public var cppEnumValue: MblMwAlsLtr329IntegrationTime {
            switch self {
                case .ms50: return MBL_MW_ALS_LTR329_TIME_50ms
                case .ms100: return MBL_MW_ALS_LTR329_TIME_100ms
                case .ms150: return MBL_MW_ALS_LTR329_TIME_150ms
                case .ms200: return MBL_MW_ALS_LTR329_TIME_200ms
                case .ms250: return MBL_MW_ALS_LTR329_TIME_250ms
                case .ms300: return MBL_MW_ALS_LTR329_TIME_300ms
                case .ms350: return MBL_MW_ALS_LTR329_TIME_350ms
                case .ms400: return MBL_MW_ALS_LTR329_TIME_400ms
            }
        }

        public var displayName: String { String(rawValue) }
    }

    enum TR329MeasurementRate: Int, CaseIterable, IdentifiableByRawValue {
        case ms50   = 50
        case ms100  = 100
        case ms200  = 200
        case ms500  = 500
        case ms1000 = 1000
        case ms2000 = 2000

        public var cppEnumValue: MblMwAlsLtr329MeasurementRate {
            switch self {
                case .ms50: return MBL_MW_ALS_LTR329_RATE_50ms
                case .ms100: return MBL_MW_ALS_LTR329_RATE_100ms
                case .ms200: return MBL_MW_ALS_LTR329_RATE_200ms
                case .ms500: return MBL_MW_ALS_LTR329_RATE_500ms
                case .ms1000: return MBL_MW_ALS_LTR329_RATE_1000ms
                case .ms2000: return MBL_MW_ALS_LTR329_RATE_2000ms
            }
        }

        public var displayName: String { String(rawValue) }
    }

}
