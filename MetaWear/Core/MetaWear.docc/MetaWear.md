# ``MetaWear``

Develop Bluetooth Low Energy apps using our sensors and `Combine`

This SDK makes configuring and retrieving data streams from MetaWear devices easy, flexible, and concise by leveraging Apple's `Combine` framework across iOS, macOS, watchOS, and tvOS.

If you're new to Bluetooth and MetaWear, this SDK offers SwiftUI-like presets that entirely abstract any interactions with the C++ library. You can try the <doc:/tutorials/MetaWear> tutorial and read the source of our MetaBase apps to get up to speed.

For those who want more control, this SDK also exposes publishers convenient for working with `OpaquePointer` chains and your own C++ commands. See <doc:Migrating-From-Bolts>.

![MetaMotion S.](metamotion.png)

## Basics

You can build an asynchronous `Combine` pipeline by combining:
1. a start condition — e.g., upon disconnection (to perhaps auto-reconnect)
2. an action — e.g., `read`, `stream`, `log`, `downloadLog`, `command`
3. a sensor configuration suggested by code completion
4. any of the many `Combine` operators for manipulating streams of data or events

###### Example 1: Upon connection, stream accelerometer vectors, switching to main for UI updates ######
```
metawear
   .publishWhenConnected()
   .first()
   .stream(.accelerometer(rate: .hz100, range: .g2)
   .map { myProcessingFunction($0) }
   .receive(on: DispatchQueue.main)
```

If you're unfamiliar with `Combine`, see <doc:/tutorials/MetaWear/Renaming-Devices>. This block above is a recipe that you can pass around for further specialization. Execution begins only when you subscribe, which the tutorial explains.

To discover nearby MetaWears, use ``MetaWearScanner``.

###### Example 2: Scan for nearby devices, reporting only unique discoveries ######
```swift
let scanner = MetaWearScanner.sharedRestore()
scanner.startScan(allowDuplicates: false)
scanner.didDiscoverDeviceUniqued
       .recieve(on: DispatchQueue.main)
       .sink { [weak self] device in 
           self?.devices.append(device)
       }
       .store(in: &subs)
```


## Topics

### Getting Started

- <doc:/tutorials/MetaWear>
- <doc:Migrating-From-Bolts>

### Essentials

Using any ``MetaPublisher`` ensures calls into the C++ library and reads of any properties occur on the ``MetaWear/apiAccessQueue``.

- ``MetaWear/MetaWearScanner``
- ``MetaWear/MetaWear``
- ``MetaWear/MetaPublisher``

### Identification

- ``DeviceInformation``
- ``MetaWear/MetaWear/readCharacteristic(_:)``
- ``MWServiceCharacteristic``

### Connecting
- ``MetaWearScanner``
- ``MetaWearScanner/startScan(allowDuplicates:)``
- ``MetaWearScanner/didDiscoverUniqued``
- ``MetaWear/MetaWear/connectPublisher()``

### Stream & Log Sensors

- ``MWDataSignal``
- ``MWData``
- ``MetaWear/MetaWear/publishIfConnected()``
- ``MetaWear/MetaWear/publishWhenConnected()``
- ``MetaWear/MetaWear/publishWhenDisconnected()``
- ``MetaWear/MetaWear/publish()``
- ``MWDataSignal``
- ``MWLoggerName``
- ``MWReadable``
- ``MWLoggable``
- ``MWStreamable``
- ``MWPollable``
- ``Timestamped``
- ``MWBoard``
- <doc:/tutorials/MetaWear/Connecting-To-A-MetaWear>

### Firmware

- ``MetaWearFirmwareServer``
- ``FirmwareBuild``
- ``MetaWearFirmwareServer/fetchRelevantFirmwareUpdate(for:)``
- ``MetaWearFirmwareServer/updateFirmware(on:delegate:build:)``

### Console Logging

- ``ConsoleLogger``
- ``LogLevel``
- ``LogDelegate``

### Errors

- ``MetaWearError``
- ``FirmwareError``

### C++ Bridging

You can use the bridge functions. These enums provide an easy reference to C++ constants. You can use functions too.
+ ``bridge(obj:)``
+ ``bridge(ptr:)``
+ ``bridgeRetained(obj:)``
+ ``bridgeTransfer(ptr:)``

### Accelerometer

- ``MWAccelerometer``
- ``MODULE_ACC_TYPE_BMI270``
- ``MODULE_ACC_TYPE_BMI160``
- ``MODULE_ACC_TYPE_BMA255``
- ``MODULE_ACC_TYPE_MMA8452Q``
- ``ACC_ACCEL_X_AXIS_INDEX``
- ``ACC_ACCEL_Y_AXIS_INDEX``
- ``ACC_ACCEL_Z_AXIS_INDEX``

### Ambient Light

- ``MWAmbientLightGain``
- ``MWAmbientLightTR329IntegrationTime``
- ``MWAmbientLightTR329MeasurementRate``

### Battery

- ``SETTINGS_BATTERY_CHARGE_INDEX``
- ``SETTINGS_BATTERY_VOLTAGE_INDEX``
- ``SETTINGS_CHARGE_STATUS_UNSUPPORTED``
- ``SETTINGS_POWER_STATUS_UNSUPPORTED``

### Barometer

- ``MWBarometer``
- ``MODULE_BARO_TYPE_BME280``
- ``MODULE_BARO_TYPE_BMP280``

### GPIO

- ``MWGPIO``
- ``GPIO_UNUSED_PIN``

### Gyroscope

- ``MWGyroscope``
- ``MODULE_GYRO_TYPE_BMI160``
- ``MODULE_GYRO_TYPE_BMI270``
- ``GYRO_ROTATION_X_AXIS_INDEX``
- ``GYRO_ROTATION_Y_AXIS_INDEX``
- ``GYRO_ROTATION_Z_AXIS_INDEX``

### Hygrometer

- ``MWHumidityOversampling``

### I2C

- ``MWI2CSize``

### LED

- ``MBLColor``
- ``LED_REPEAT_INDEFINITELY``
- ``CD_TCS34725_ADC_RED_INDEX``
- ``CD_TCS34725_ADC_GREEN_INDEX``
- ``CD_TCS34725_ADC_BLUE_INDEX``
- ``CD_TCS34725_ADC_CLEAR_INDEX``

### Magnetometer

- ``MAG_BFIELD_X_AXIS_INDEX``
- ``MAG_BFIELD_Y_AXIS_INDEX``
- ``MAG_BFIELD_Z_AXIS_INDEX``

### Sensor Fusion

- ``MWSensorFusionMode``
- ``MWSensorFusionOutputType``
- ``SENSOR_FUSION_CALIBRATION_ACCURACY_HIGH``
- ``SENSOR_FUSION_CALIBRATION_ACCURACY_LOW``
- ``SENSOR_FUSION_CALIBRATION_ACCURACY_MEDIUM``
- ``SENSOR_FUSION_CALIBRATION_ACCURACY_UNRELIABLE``

### Thermometer

- ``MWTemperatureSource``

### Status

- ``STATUS_OK``
- ``STATUS_ERROR_UNSUPPORTED_PROCESSOR``
- ``STATUS_ERROR_TIMEOUT``
- ``STATUS_ERROR_ENABLE_NOTIFY``
- ``STATUS_ERROR_SERIALIZATION_FORMAT``
- ``STATUS_WARNING_INVALID_PROCESSOR_TYPE``
- ``STATUS_WARNING_INVALID_RESPONSE``
- ``STATUS_WARNING_UNEXPECTED_SENSOR_DATA``

### Module Detection
- ``MODULE_TYPE_NA``

### Etc
- ``ADDRESS_TYPE_RANDOM_STATIC``
- ``ADDRESS_TYPE_PUBLIC``
- ``ADDRESS_TYPE_PRIVATE_RESOLVABLE``
- ``ADDRESS_TYPE_PRIVATE_NON_RESOLVABLE``
