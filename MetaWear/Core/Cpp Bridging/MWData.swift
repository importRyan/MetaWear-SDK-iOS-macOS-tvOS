// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import MetaWearCpp

/// Useful when interacting with the C++ library.
///
/// This holds data from the MetaWear because the
/// C++ library destroys `MblMwData` objects after
/// a callback.
///
public struct MWData {
    public let timestamp: Date
    let data: [UInt8]
    let typeId: MblMwDataTypeId
    
    public func valueAs<T>() -> T {
        withUnsafePointer(to: data) { p -> T in
            cast(length: UInt8(data.endIndex), type_id: typeId, value: UnsafeRawPointer(p))
        }
    }
}

// MARK: - Log Wrapper

public extension MWData {

    struct LogDownload {
        public let logger: MWLogger
        public let data: [MWData]

        public init(logger: MWLogger, data: [MWData]) {
            self.logger = logger
            self.data = data
        }
    }
}

// MARK: - Move from C++

extension MblMwData {
    public func copy() -> MWData {
        let arrayPtr = value.bindMemory(to: UInt8.self, capacity: Int(length))
        return MWData(timestamp: timestamp,
                            data: Array(UnsafeBufferPointer(start: arrayPtr, count: Int(length))),
                            typeId: type_id)
    }
    public var timestamp: Date {
        let date = Date(timeIntervalSince1970: Double(epoch) / 1000.0)
        let milliseconds = epoch%1000
        return Calendar.current.date(byAdding: .nanosecond, value: Int(milliseconds), to: date)!
    }
    public func valueAs<T>() -> T {
        cast(length: length, type_id: type_id, value: value)
    }
    public func extraAs<T>() -> T {
        extra.bindMemory(to: T.self, capacity: 1).pointee
    }
}

// MARK: - Cast

fileprivate func cast<T>(length: UInt8, type_id: MblMwDataTypeId, value: UnsafeRawPointer) -> T {
    guard type_id != MBL_MW_DT_ID_STRING else {
        assert(T.self == String.self || T.self == String?.self)
        return String(cString: value.assumingMemoryBound(to: CChar.self)) as! T
    }
    guard type_id != MBL_MW_DT_ID_BYTE_ARRAY else {
        assert(T.self == [UInt8].self)
        let buffer = UnsafeRawBufferPointer(start: value, count: Int(length))
        return Array(buffer) as! T
    }
    guard type_id != MBL_MW_DT_ID_DATA_ARRAY else {
        assert(T.self == [MblMwData].self)
        let count = Int(length) / MemoryLayout<UnsafePointer<MblMwData>>.size
        let pointer = value.bindMemory(to: UnsafePointer<MblMwData>.self, capacity: count)
        let buffer = UnsafeBufferPointer(start: pointer, count: count)
        return buffer.map { $0.pointee } as! T
    }
    // Generalized flow
    assert(MemoryLayout<T>.size == length)
    assertMatching(T.self, type_id)
    return value.bindMemory(to: T.self, capacity: 1).pointee
}

fileprivate func assertMatching<T>(_ type: T.Type, _ id: MblMwDataTypeId) {
    switch id {
        case MBL_MW_DT_ID_UINT32:                    assert(T.self == UInt32.self)
        case MBL_MW_DT_ID_FLOAT:                     assert(T.self == Float.self)
        case MBL_MW_DT_ID_CARTESIAN_FLOAT:           assert(T.self == MblMwCartesianFloat.self)
        case MBL_MW_DT_ID_INT32:                     assert(T.self == Int32.self)
        case MBL_MW_DT_ID_BATTERY_STATE:             assert(T.self == MblMwBatteryState.self)
        case MBL_MW_DT_ID_TCS34725_ADC:              assert(T.self == MblMwTcs34725ColorAdc.self)
        case MBL_MW_DT_ID_EULER_ANGLE:               assert(T.self == MblMwEulerAngles.self)
        case MBL_MW_DT_ID_QUATERNION:                assert(T.self == MblMwQuaternion.self)
        case MBL_MW_DT_ID_CORRECTED_CARTESIAN_FLOAT: assert(T.self == MblMwCorrectedCartesianFloat.self)
        case MBL_MW_DT_ID_OVERFLOW_STATE:            assert(T.self == MblMwOverflowState.self)
        case MBL_MW_DT_ID_SENSOR_ORIENTATION:        assert(T.self == MblMwSensorOrientation.self)
        case MBL_MW_DT_ID_LOGGING_TIME:              assert(T.self == MblMwLoggingTime.self)
        case MBL_MW_DT_ID_BTLE_ADDRESS:              assert(T.self == MblMwBtleAddress.self)
        case MBL_MW_DT_ID_BOSCH_ANY_MOTION:          assert(T.self == MblMwBoschAnyMotion.self)
        case MBL_MW_DT_ID_BOSCH_GESTURE:             assert(T.self == MblMwBoschGestureType.self)
        case MBL_MW_DT_ID_CALIBRATION_STATE:         assert(T.self == MblMwCalibrationState.self)
        case MBL_MW_DT_ID_BOSCH_TAP:                 assert(T.self == MblMwBoschTap.self)
        default: fatalError("unknown data type")
    }
}
