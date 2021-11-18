////Copyright

import Foundation
import MetaWearCpp
import Combine
import MetaWear

// MARK: - Signals



// MARK: - Discoverable Presets



// MARK: - C++ Constants

public enum MWSensorFusionOutputType: Int, CaseIterable, IdentifiableByRawValue {
    case eulerAngles
    case quaternion
    case gravity
    case linearAcceleration

    public var cppEnumValue: MblMwSensorFusionData {
        switch self {
            case .eulerAngles: return MBL_MW_SENSOR_FUSION_DATA_EULER_ANGLE
            case .quaternion: return MBL_MW_SENSOR_FUSION_DATA_QUATERNION
            case .gravity: return MBL_MW_SENSOR_FUSION_DATA_GRAVITY_VECTOR
            case .linearAcceleration: return MBL_MW_SENSOR_FUSION_DATA_LINEAR_ACC
        }
    }

    public var channelCount: Int { channelLabels.endIndex }

    public var channelLabels: [String] {
        switch self {
            case .eulerAngles: return ["Pitch", "Roll", "Yaw"]
            case .quaternion: return ["W", "X", "Y", "Z"]
            case .gravity: return ["X", "Y", "Z"]
            case .linearAcceleration: return ["X", "Y", "Z"]
        }
    }

    public var fullName: String {
        switch self {
            case .eulerAngles: return "Euler Angles"
            case .quaternion: return "Quaternion"
            case .gravity: return "Gravity"
            case .linearAcceleration: return "Linear Acceleration"
        }
    }

    public var shortFileName: String {
        switch self {
            case .eulerAngles: return "Euler"
            case .quaternion: return "Quaternion"
            case .gravity: return "Gravity"
            case .linearAcceleration: return "LinearAcc"
        }
    }

    public var scale: Float {
        switch self {
            case .eulerAngles: return 360
            case .quaternion: return 1
            case .gravity: return 1
            case .linearAcceleration: return 8
        }
    }

}

public enum MWSensorFusionMode: Int, CaseIterable, IdentifiableByRawValue {
    case ndof
    case imuplus
    case compass
    case m4g

    var cppValue: UInt32 { UInt32(rawValue + 1) }

    var cppMode: MblMwSensorFusionMode { MblMwSensorFusionMode(cppValue) }

    var displayName: String {
        switch self {
            case .ndof: return "NDoF"
            case .imuplus: return "IMUPlus"
            case .compass: return "Compass"
            case .m4g: return "M4G"
        }
    }

}
