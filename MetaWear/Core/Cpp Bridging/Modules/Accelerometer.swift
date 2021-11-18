////Copyright

import Foundation
import MetaWearCpp
import Combine


// MARK: - Discoverable Presets

extension MWStreamable where Self == MWAccelerometer {

    /// Prepares the accelerometer module. If any
    ///  parameters are nil, the device uses the
    ///  last setting or a default.
    ///
    /// - Parameters:
    ///   - rate: Sampling frequency (if nil, device uses last setting or a default)
    ///   - gravity: Range of detection
    /// - Returns: Accelerometer module configuration
    static func accelerometer(rate: Self.SampleFrequency? = nil, gravity: Self.GravityRange? = nil) -> Self {
        Self(rate: rate, gravity: gravity)
    }
}

extension MWStreamable where Self == MWOrientationSensor {
    static var orientation: Self { Self() }
}

extension MWStreamable where Self == MWStepDetector {
    static func steps(sensitivity: MWAccelerometer.StepCounterSensitivity? = nil) -> Self {
        Self(sensitivity: sensitivity)
    }
}

extension MWDataConvertible where Self == MWStepCounter {
    static var steps: Self { Self() }
}


// MARK: - Signals

public struct MWAccelerometer: MWDataConvertible, MWLoggable, MWStreamable {

    public typealias DataType = SIMD3<Float>
    public let loggerName: MWLoggerName = .acceleration

    public var gravity: GravityRange? = nil
    public var rate: SampleFrequency? = nil
    public var needsConfiguration: Bool { gravity != nil || rate != nil }

    public init(rate: SampleFrequency?, gravity: GravityRange?) {
        self.gravity = gravity
        self.rate = rate
    }

    public func convert(data: MblMwData) -> Timestamped<DataType> {
        let value = data.valueAs() as MblMwCartesianFloat
        return (time: data.timestamp, .init(x: value.x, y: value.y, z: value.z))
    }

    public func streamSignal(board: MWBoard) -> MWDataSignal? {
        mbl_mw_acc_bosch_get_acceleration_data_signal(board)
    }

    public func streamConfigure(board: MWBoard) {
        guard needsConfiguration else { return }
        if let range = gravity { mbl_mw_acc_bosch_set_range(board, range.cppEnumValue) }
        if let rate = rate { mbl_mw_acc_set_odr(board, rate.cppOdrValue) }
        mbl_mw_acc_bosch_write_acceleration_config(board)
    }

    public func streamStart(board: MWBoard) {
        mbl_mw_acc_enable_acceleration_sampling(board)
        mbl_mw_acc_start(board)
    }

    public func streamCleanup(board: MWBoard) {
        mbl_mw_acc_stop(board)
        mbl_mw_acc_disable_acceleration_sampling(board)
    }

    public func loggerCleanup(board: MWBoard) {
        self.streamCleanup(board: board)
        guard Model(board: board) == .bmi270 else { return }
        mbl_mw_logging_flush_page(board)
    }
}

public struct MWOrientationSensor: MWDataConvertible, MWStreamable {

    public typealias DataType = MWAccelerometer.Orientation

    public func convert(data: MWData) -> Timestamped<DataType> {
        let value = data.valueAs() as MblMwSensorOrientation
        return (data.timestamp, .init(sensor: value)!)
    }

    public func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        guard mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_ACCELEROMETER) == MBL_MW_MODULE_ACC_TYPE_BMI160 else {
            throw MetaWearError.operationFailed("Orientation requires a BMI160 module, which this device lacks.")
        }
        return mbl_mw_acc_bosch_get_orientation_detection_data_signal(board)
    }

    public func streamConfigure(board: MWBoard) {}

    public func streamStart(board: MWBoard) {
        mbl_mw_acc_bosch_enable_orientation_detection(board)
        mbl_mw_acc_start(board)
    }

    public func streamCleanup(board: MWBoard) {
        mbl_mw_acc_stop(board)
        mbl_mw_acc_bosch_disable_orientation_detection(board)
    }
}

public struct MWStepDetector: MWDataConvertible, MWStreamable {

    public typealias DataType = Int

    public var sensitivity: MWAccelerometer.StepCounterSensitivity? = nil
    public var needsConfiguration: Bool { sensitivity != nil }

    public init(sensitivity: MWAccelerometer.StepCounterSensitivity?) {
        self.sensitivity = sensitivity
    }

    /// Requires counting steps by counting each closure returned as one step
    public func convert(data: MblMwData) -> Timestamped<DataType> {
        let value = data.valueAs() as Int32
        return (data.timestamp, Int(value))
    }

    public func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        fatalError("Get correct methods")
        guard mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_ACCELEROMETER) == MBL_MW_MODULE_ACC_TYPE_BMI160 else {
            throw MetaWearError.operationFailed("Steps requires a BMI160 module, which this device lacks.")
        }
        return mbl_mw_acc_bosch_get_orientation_detection_data_signal(board)
    }

    public func streamConfigure(board: MWBoard) {
        guard let sensitivity = sensitivity else { return }
        mbl_mw_acc_bmi160_set_step_counter_mode(board, sensitivity.cppEnumValue)
        mbl_mw_acc_bmi160_write_step_counter_config(board)
    }

    public func streamStart(board: MWBoard) {
        mbl_mw_acc_bmi160_enable_step_detector(board)
        mbl_mw_acc_start(board)
    }

    public func streamCleanup(board: MWBoard) {
        mbl_mw_acc_stop(board)
        mbl_mw_acc_bmi160_disable_step_detector(board)
    }
}

public struct MWStepCounter: MWDataConvertible {
    public typealias DataType = Int32
}


// MARK: - C++ Constants

extension MWAccelerometer {

    public enum GravityRange: Int, CaseIterable, IdentifiableByRawValue {
        case g2  = 2
        case g4  = 4
        case g8  = 8
        case g16 = 16

        /// Raw Cpp constant
        public var cppEnumValue: MblMwAccBoschRange {
            switch self {
                case .g2:  return MBL_MW_ACC_BOSCH_RANGE_2G
                case .g4:  return MBL_MW_ACC_BOSCH_RANGE_4G
                case .g8:  return MBL_MW_ACC_BOSCH_RANGE_8G
                case .g16: return MBL_MW_ACC_BOSCH_RANGE_16G
            }
        }
    }

    public enum SampleFrequency: Float, CaseIterable, IdentifiableByRawValue {
        // Too fast to stream by Bluetooth Low Energy.
        case hz800  = 800
        // Too fast to stream by Bluetooth Low Energy.
        case hz400  = 400
        // Too fast to stream by Bluetooth Low Energy.
        case hz200  = 200
        case hz100  = 100
        case hz50   = 50
        case hz12_5 = 12.5

        /// Returns an integer string, except for 12.5 hz.
        public var frequencyLabel: String {
            switch self {
                case .hz12_5: return "12.5"
                default: return String(format: "%1.0f", rawValue)
            }
        }

        public var cppOdrValue: Float { rawValue }
    }

    /// Available on the BMI160 only.
    public enum StepCounterSensitivity: String, CaseIterable, IdentifiableByRawValue {
        case normal
        case sensitive
        case robust

        /// Raw Cpp constant
        public var cppEnumValue: MblMwAccBmi160StepCounterMode {
            switch self {
                case .normal:    return MBL_MW_ACC_BMI160_STEP_COUNTER_MODE_NORMAL
                case .sensitive: return MBL_MW_ACC_BMI160_STEP_COUNTER_MODE_SENSITIVE
                case .robust:    return MBL_MW_ACC_BMI160_STEP_COUNTER_MODE_ROBUST
            }
        }
    }


    public enum Model: String, CaseIterable, IdentifiableByRawValue {
        case bmi270
        case bmi160

        /// Raw Cpp constant
        public var int8Value: UInt8 {
            switch self {
                case .bmi270: return MBL_MW_MODULE_ACC_TYPE_BMI270
                case .bmi160: return MBL_MW_MODULE_ACC_TYPE_BMI160
            }
        }

        /// Cpp constant for Swift
        public var int32Value: Int32 { Int32(int8Value) }

        public init?(value: Int32) {
            switch value {
                case Self.bmi270.int32Value: self = .bmi270
                case Self.bmi160.int32Value: self = .bmi160
                default: return nil
            }
        }

        public init?(board: OpaquePointer?) {
            let accelerometer = mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_ACCELEROMETER)
            self.init(value: accelerometer)
        }
    }

    public enum Orientation: String, CaseIterable, IdentifiableByRawValue {
        case faceUpPortraitUpright
        case faceUpPortraitUpsideDown
        case faceUpLandscapeLeft
        case faceUpLandscapeRight

        case faceDownPortraitUpright
        case faceDownPortraitUpsideDown
        case faceDownLandscapeLeft
        case faceDownLandscapeRight

        /// Raw Cpp constant
        public var cppEnumValue: MblMwSensorOrientation {
            switch self {
                case .faceUpPortraitUpright:      return MBL_MW_SENSOR_ORIENTATION_FACE_UP_PORTRAIT_UPRIGHT
                case .faceUpPortraitUpsideDown:   return MBL_MW_SENSOR_ORIENTATION_FACE_UP_PORTRAIT_UPSIDE_DOWN
                case .faceUpLandscapeLeft:        return MBL_MW_SENSOR_ORIENTATION_FACE_UP_LANDSCAPE_LEFT
                case .faceUpLandscapeRight:       return MBL_MW_SENSOR_ORIENTATION_FACE_UP_LANDSCAPE_RIGHT

                case .faceDownPortraitUpright:    return MBL_MW_SENSOR_ORIENTATION_FACE_DOWN_PORTRAIT_UPRIGHT
                case .faceDownPortraitUpsideDown: return MBL_MW_SENSOR_ORIENTATION_FACE_DOWN_PORTRAIT_UPSIDE_DOWN
                case .faceDownLandscapeLeft:      return MBL_MW_SENSOR_ORIENTATION_FACE_DOWN_LANDSCAPE_LEFT
                case .faceDownLandscapeRight:     return MBL_MW_SENSOR_ORIENTATION_FACE_DOWN_LANDSCAPE_RIGHT
            }
        }

        public var nameOnTwoLines: String {
            switch self {
                case .faceUpPortraitUpright:        return "Portrait Upright\nFace Up"
                case .faceUpPortraitUpsideDown:     return "Portrait Upsidedown\nFace Up"
                case .faceUpLandscapeLeft:          return "Landscape Left\nFace Up"
                case .faceUpLandscapeRight:         return "Landscape Right\nFace Up"
                case .faceDownPortraitUpright:      return "Portrait Upright\nFace Down"
                case .faceDownPortraitUpsideDown:   return "Portrait Upsidedown\nFace Down"
                case .faceDownLandscapeLeft:        return "Landscape Left\nFace Down"
                case .faceDownLandscapeRight:       return "Landscape Right\nFace Down"
            }
        }

        public init?(sensor: MblMwSensorOrientation) {
            guard let match = Self.allCases.first(where: { $0.cppEnumValue == sensor })
            else { return nil }
            self = match
        }
    }

}
