# VitalTrack SDK
VitalTrack SDK is a comprehensive solution designed to facilitate the integration and management of Bluetooth Low Energy (BLE) devices within Flutter applications. The SDK provides a robust set of tools for scanning, connecting, and interacting with BLE devices, making it an ideal choice for developers working on health tracking, fitness, or any IoT projects requiring BLE communication.

## Features
1. Bluetooth Device Scanning: Discover nearby BLE devices and list them for user selection.
2. Device Connection: Seamlessly connect to BLE devices and manage connection states.
3. Service and Characteristic Discovery: Automatically discover and interact with device services and characteristics.
4. Data Subscription: Subscribe to data streams from connected devices, including PPG, ACC, Gyro, and Mag data.
5. Command Writing: Send commands to connected devices to control their operations.
6. Error Handling and Reconnection: Robust handling of connection errors with automatic reconnection attempts.

## Usage
Import the necessary packages and initialize the BleController in your main widget:
### Initialization
```   
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controller/bleController.dart';
import 'view/bleScreen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      home: BleScreen(),
    );
  }
}

```   

### BLE Controller
The BleController handles all BLE operations. It scans for devices, connects to them, discovers services and characteristics, and subscribes to data streams.
```   
class BleController extends GetxController {
  // Initialize the BLE controller and variables

  @override
  void onInit() {
    super.onInit();
    _ble.statusStream.listen((status) {
      if (status == BleStatus.ready) {
        startScan();
      }
    });
  }

  void startScan() {
    // Start scanning for BLE devices
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    // Connect to a BLE device and manage connection states
  }

  void discoverServices(DiscoveredDevice device) async {
    // Discover services and characteristics
  }

  void subscribeToCharacteristic(QualifiedCharacteristic characteristic) {
    // Subscribe to characteristic notifications and handle incoming data
  }

  void writeCMDToDevice(String cmd) async {
    // Write commands to the connected device
  }

  @override
  void onClose() {
    stopScan();
    super.onClose();
  }
}
```   

### BLE Screen
The BleScreen widget provides the user interface for scanning and connecting to BLE devices. It lists discovered devices and handles user interactions.
```   
class BleScreen extends StatelessWidget {
  final BleController bleController = Get.put(BleController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // UI components for scanning and displaying devices
          ],
        ),
      ),
    );
  }

  Widget listItem(DiscoveredDevice device) {
    // Build list item for each discovered device
  }

  void onTap(DiscoveredDevice device) {
    // Handle device selection and connection
  }
}

```   


### Measure Screen
The MeasureScreen widget is used for displaying and recording data from the connected BLE device.
```   
class MeasureScreen extends StatefulWidget {
  @override
  _MeasureScreenState createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("VitalTrack SDK"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // UI components for displaying data
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Handle start/stop recording
        },
        child: Obx(() {
          // Update FAB icon based on recording state
        }),
      ),
    );
  }
}
```   

## Permissions
Ensure to request the necessary permissions for Bluetooth and location services. The BleScreen and MeasureScreen widgets include methods to request these permissions using the permission_handler package.

## Contributing
Contributions are welcome! Please submit pull requests or open issues for any bugs or feature requests.

## Requirements
Dart SDK >=2.12.0 <3.0.0
Flutter SDK >=2.0.0
Android API Level 21+
