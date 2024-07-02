# VitalTrack SDK
VitalTrack SDK is a comprehensive solution designed to facilitate the integration and management of Bluetooth Low Energy (BLE) devices within Flutter applications. The SDK provides a robust set of tools for scanning, connecting, and interacting with BLE devices, making it an ideal choice for developers working on health tracking, fitness, or any IoT projects requiring BLE communication.

## Features
1. Bluetooth Device Scanning: Discover nearby BLE devices and list them for user selection.
2. Device Connection: Seamlessly connect to BLE devices and manage connection states.
3. Service and Characteristic Discovery: Automatically discover and interact with device services and characteristics.
4. Data Subscription: Subscribe to data streams from connected devices, including PPG, ACC, Gyro, and Mag data.
5. Command Writing: Send commands to connected devices to control their operations.
6. Error Handling and Reconnection: Robust handling of connection errors with automatic reconnection attempts.


## Installation
```   
Add the following dependencies to your pubspec.yaml file:
dependencies:
  flutter:
    sdk: flutter
  get:
  flutter_reactive_ble:
  intl:
  permission_handler:
  path_provider:
```   
