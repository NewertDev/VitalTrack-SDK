# Newert VitalTrack SDK

The Newert VitalTrack SDK is a Flutter package that enables scanning and connecting to Bluetooth LE devices and collecting biometric data. Currently, it supports only Android.

## Features

- Scan and connect to Bluetooth LE devices
- Collect PPG, ACC, Gyro, and Mag data
- Real-time communication with devices

## Installation

Add the dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_reactive_ble: ^5.0.1
  get: ^4.6.5
  intl: ^0.17.0
  path_provider: ^2.0.9
  permission_handler: ^10.2.0
  newert_vitaltrack: ^1.0.0

