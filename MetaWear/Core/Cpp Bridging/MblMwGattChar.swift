// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import CoreBluetooth
import MetaWearCpp


/// Helpers for dealing with the C++ version of GATT Service/Characteristic
extension MblMwGattChar: Hashable {
    var serviceUUID: CBUUID {
        var service_uuid_high_swap = service_uuid_high.byteSwapped
        var data = Data(buffer: UnsafeBufferPointer(start: &service_uuid_high_swap, count: 1))
        var service_uuid_low_swap = service_uuid_low.byteSwapped
        data.append(UnsafeBufferPointer(start: &service_uuid_low_swap, count: 1))
        return CBUUID(data: data)
    }
    var characteristicUUID: CBUUID {
        var uuid_high_swap = uuid_high.byteSwapped
        var data = Data(buffer: UnsafeBufferPointer(start: &uuid_high_swap, count: 1))
        var uuid_low_swap = uuid_low.byteSwapped
        data.append(UnsafeBufferPointer(start: &uuid_low_swap, count: 1))
        return CBUUID(data: data)
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(service_uuid_high)
        hasher.combine(service_uuid_low)
        hasher.combine(uuid_high)
        hasher.combine(uuid_low)
    }
    public static func ==(lhs: MblMwGattChar, rhs: MblMwGattChar) -> Bool {
        return lhs.service_uuid_high == rhs.service_uuid_high &&
            lhs.service_uuid_low == rhs.service_uuid_low &&
            lhs.uuid_high == rhs.uuid_high &&
            lhs.uuid_low == rhs.uuid_low
    }
}
