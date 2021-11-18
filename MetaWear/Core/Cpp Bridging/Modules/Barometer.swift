////Copyright

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

public struct MWBarometer {

}

// MARK: - Discoverable Presets



// MARK: - C++ Constants

public extension MWBarometer {

    enum StandbyTime: Int, CaseIterable, IdentifiableByRawValue {
        case ms0_5
        /// Unavailable on the BMP module
        case ms10
        /// Unavailable on the BMP module
        case ms20
        case ms62_5
        case ms125
        case ms250
        case ms500
        case ms1000

        /// Unavailable on the BME module
        case ms2000
        /// Unavailable on the BME module
        case ms4000

        public static let BMPoptions: [Self] = [
            .ms0_5,
    // Missing these two options
            .ms62_5,
            .ms125,
            .ms250,
            .ms500,
            .ms1000,
            .ms2000,
            .ms4000
        ]

        public static let BMEoptions: [Self] = [
            .ms0_5,
            .ms10,
            .ms20,
            .ms62_5,
            .ms125,
            .ms250,
            .ms500,
            .ms1000
            // Missing these two options
        ]

        /// Returns an Int except for 0.5 and 62.5 ms
        public var displayName: String {
            switch self {
                case .ms0_5: return "0.5"
                case .ms62_5: return "62.5"
                default: return String(rawValue)
            }
        }

        public var BME_cppEnumValue: MblMwBaroBme280StandbyTime {
            switch self {
                case .ms0_5: return MBL_MW_BARO_BME280_STANDBY_TIME_0_5ms
                case .ms10: return MBL_MW_BARO_BME280_STANDBY_TIME_10ms
                case .ms20: return MBL_MW_BARO_BME280_STANDBY_TIME_20ms
                case .ms62_5: return MBL_MW_BARO_BME280_STANDBY_TIME_62_5ms
                case .ms125: return MBL_MW_BARO_BME280_STANDBY_TIME_125ms
                case .ms250: return MBL_MW_BARO_BME280_STANDBY_TIME_250ms
                case .ms500: return MBL_MW_BARO_BME280_STANDBY_TIME_500ms
                case .ms1000: return MBL_MW_BARO_BME280_STANDBY_TIME_1000ms

                case .ms2000: return MBL_MW_BARO_BME280_STANDBY_TIME_1000ms // Not present
                case .ms4000: return MBL_MW_BARO_BME280_STANDBY_TIME_1000ms // Not present
            }
        }

        public var BMP_cppEnumValue: MblMwBaroBmp280StandbyTime {
            switch self {
                case .ms0_5: return MBL_MW_BARO_BMP280_STANDBY_TIME_0_5ms

                case .ms62_5: return MBL_MW_BARO_BMP280_STANDBY_TIME_62_5ms
                case .ms125: return MBL_MW_BARO_BMP280_STANDBY_TIME_125ms
                case .ms250: return MBL_MW_BARO_BMP280_STANDBY_TIME_250ms
                case .ms500: return MBL_MW_BARO_BMP280_STANDBY_TIME_500ms
                case .ms1000: return MBL_MW_BARO_BMP280_STANDBY_TIME_1000ms
                case .ms2000: return MBL_MW_BARO_BMP280_STANDBY_TIME_2000ms
                case .ms4000: return MBL_MW_BARO_BMP280_STANDBY_TIME_4000ms

                case .ms10: return MBL_MW_BARO_BMP280_STANDBY_TIME_62_5ms // Not present
                case .ms20: return MBL_MW_BARO_BMP280_STANDBY_TIME_62_5ms // Not present
            }
        }
    }

    enum IIRFilter: Int, CaseIterable, IdentifiableByRawValue {
        case off
        case avg2
        case avg4
        case avg8
        case avg16

        public var cppEnumValue: MblMwBaroBoschIirFilter {
            switch self {
                case .off: return MBL_MW_BARO_BOSCH_IIR_FILTER_OFF
                case .avg2: return MBL_MW_BARO_BOSCH_IIR_FILTER_AVG_2
                case .avg4: return MBL_MW_BARO_BOSCH_IIR_FILTER_AVG_4
                case .avg8: return MBL_MW_BARO_BOSCH_IIR_FILTER_AVG_8
                case .avg16: return MBL_MW_BARO_BOSCH_IIR_FILTER_AVG_16
            }
        }

        public var displayName: String {
            switch self {
                case .off: return "Off"
                case .avg2: return "2"
                case .avg4: return "4"
                case .avg8: return "8"
                case .avg16: return "16"
            }
        }
    }

    enum Oversampling: Int, CaseIterable, IdentifiableByRawValue {
        case ultraLowPower
        case lowPower
        case standard
        case high
        case ultraHigh

        public var cppEnumValue: MblMwBaroBoschOversampling {
            switch self {
                case .ultraLowPower: return MBL_MW_BARO_BOSCH_OVERSAMPLING_ULTRA_LOW_POWER
                case .lowPower: return MBL_MW_BARO_BOSCH_OVERSAMPLING_LOW_POWER
                case .standard: return MBL_MW_BARO_BOSCH_OVERSAMPLING_STANDARD
                case .high: return MBL_MW_BARO_BOSCH_OVERSAMPLING_HIGH
                case .ultraHigh: return MBL_MW_BARO_BOSCH_OVERSAMPLING_ULTRA_HIGH
            }
        }

        public var displayName: String {
            switch self {
                case .ultraLowPower: return "Ultra Low"
                case .lowPower: return "Low"
                case .standard: return "Standard"
                case .high: return "High"
                case .ultraHigh: return "Ultra High"
            }
        }
    }

    enum Model: String, CaseIterable, IdentifiableByRawValue {
        case bmp280
        case bme280

        /// Raw Cpp constant
        public var int8Value: UInt8 {
            switch self {
                case .bmp280: return MetaWearCpp.MBL_MW_MODULE_BARO_TYPE_BMP280
                case .bme280: return MetaWearCpp.MBL_MW_MODULE_BARO_TYPE_BME280
            }
        }

        /// Cpp constant for Swift
        public var int32Value: Int32 { Int32(int8Value) }

        public init?(value: Int32) {
            switch value {
                case Self.bmp280.int32Value: self = .bmp280
                case Self.bme280.int32Value: self = .bme280
                default: return nil
            }
        }

        public init?(board: OpaquePointer?) {
            let device = mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_BAROMETER)
            self.init(value: device)
        }
    }

}
