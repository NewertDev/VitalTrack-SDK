import 'package:flutter/widgets.dart';
import 'package:newert_vitaltrack/src/processing.dart';
import 'package:newert_vitaltrack/src/bleStatus.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../view/style.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controller/bleController.dart';
// import '../bluetooth/ble_controller.dart';

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  var bleController = Get.put(BleController());

  Timer? _dataTimer;

  // Start Button
  RxBool isRecording = false.obs;
  DateTime startTime = DateTime.now();

  // RxList
  RxList rxppgDataList = [0.0].obs;
  RxList rxaccDataList = [
    [0.0, 0.0, 0.0]
  ].obs;
  RxList rxgyroDataList = [
    [0.0, 0.0, 0.0]
  ].obs;
  RxList rxmagDataList = [
    [0.0, 0.0, 0.0]
  ].obs;

  @override
  void initState() {
    _requestPermissions(); // 권한 요청
    super.initState();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    super.dispose();
  }

  void _startGetDataTimer() {
    bleController.receivedPPGDataQueue.clear();
    bleController.receivedACCDataQueue.clear();
    bleController.receivedGyroDataQueue.clear();
    bleController.receivedMagDataQueue.clear();

    var dataSource = DataSource();

    _dataTimer =
        Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      List<double> ppgDataList = [];
      List<List<double>> accDataList = [];
      List<List<double>> gyroDataList = [];
      List<List<double>> magDataList = [];

      // PPG 데이터 처리
      ppgDataList.addAll(bleController.receivedPPGDataQueue);
      bleController.receivedPPGDataQueue.clear();

      // 가속도계 데이터 처리
      accDataList.addAll(bleController.receivedACCDataQueue);
      bleController.receivedACCDataQueue.clear();
      // 자이로스코프 데이터 처리
      gyroDataList.addAll(bleController.receivedGyroDataQueue);
      bleController.receivedGyroDataQueue.clear();
      // 자력계 데이터 처리
      magDataList.addAll(bleController.receivedMagDataQueue);
      bleController.receivedMagDataQueue.clear();

      if (ppgDataList.isNotEmpty) {
        List<double> resultPPG = dataSource.getScalarData(ppgDataList, 50);
        List<List<double>> resultACC = dataSource.getAxisData(accDataList, 50);
        List<List<double>> resultGyro =
            dataSource.getAxisData(gyroDataList, 50);
        List<List<double>> resultMag = dataSource.getAxisData(magDataList, 50);

        rxppgDataList.value = dataSource.getScalarData(ppgDataList, 50);
        rxaccDataList.value = dataSource.getAxisData(accDataList, 50);
        rxgyroDataList.value = dataSource.getAxisData(gyroDataList, 50);
        rxmagDataList.value = dataSource.getAxisData(magDataList, 50);

        debugPrint("PPG data for 1 seconds : $resultPPG");
        debugPrint("ACC data for 1 seconds: $resultACC");
        debugPrint("Gyro data for 1 seconds: $resultGyro");
        debugPrint("Mag data for 1 seconds: $resultMag");
      }
    });
  }

  void _stopTimer() {
    _dataTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          return;
        }
        bool shouldExit = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20.0)),
              ),
              title: const Text('앱을 종료하시겠습니까?',
                  style: AppTextStyle.bodyRegularHyperlink),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // Cancel
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black54,
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true); // Confirm
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.point,
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            );
          },
        );

        if (shouldExit) {
          bleController.writeCMDToDevice(CMD.STOP_PPG);
          bleController.writeCMDToDevice(CMD.REBOOT_PPG);
          SystemNavigator.pop(); // Exit the app
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.info),
              color: Colors.white,
              onPressed: () {
                // Show licenses
                showLicensePage(
                  context: context,
                  applicationName: 'VitalTrack',
                  applicationVersion: '1.0.0',
                );
              },
            ),
          ],
          centerTitle: true,
          elevation: 1,
          backgroundColor: AppColors.point,
          title: const Text("VitalTrack SDK"),
          titleTextStyle: AppTextStyle.subtitleLarge,
          leading: IconButton(
            onPressed: () async {
              // Show the confirmation dialog
              bool shouldExit = await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20.0)),
                    ),
                    title: const Text('앱을 종료하시겠습니까?',
                        style: AppTextStyle.bodyRegularHyperlink),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(false); // Cancel
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black54,
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(true); // Confirm
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.point,
                        ),
                        child: const Text(
                          '확인',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (shouldExit) {
                bleController.writeCMDToDevice(CMD.STOP_PPG);
                bleController.writeCMDToDevice(CMD.REBOOT_PPG);
                SystemNavigator.pop(); // Exit the app
              }
            },
            color: Colors.white,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Obx(() => Container(
                        width: 250,
                        height: 100,
                        child: Center(
                            child: Text('PPG data : ${rxppgDataList.last}')),
                      )),
                  Obx(() => Container(
                        width: 250,
                        height: 100,
                        child: Center(
                          child: Text('ACC data : ${rxaccDataList.last}'),
                        ),
                      )),
                  Obx(() => Container(
                        width: 250,
                        height: 100,
                        child: Center(
                          child: Text('Gyro data : ${rxgyroDataList.last}'),
                        ),
                      )),
                  Obx(() => Container(
                        width: 250,
                        height: 100,
                        child: Center(
                          child: Text('Mag data : ${rxmagDataList.last}'),
                        ),
                      ))
                ],
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            if (isRecording.value) {
              startTime = DateTime.now();
              startTime = DateTime.now();
              bleController.writeCMDToDevice(CMD.STOP_PPG);
              await Future.delayed(const Duration(milliseconds: 10));
              bleController.writeCMDToDevice(CMD.SETUP_DATA);
              _stopTimer();
            } else {
              bleController.writeCMDToDevice(CMD.ON_1V8);
              await Future.delayed(const Duration(milliseconds: 10));
              bleController.writeCMDToDevice(CMD.START_PPG);
              await Future.delayed(const Duration(milliseconds: 10));
              bleController.writeCMDToDevice(CMD.SETUP_DATA);
              _startGetDataTimer();
            }
            isRecording.value = !isRecording.value;
          },
          backgroundColor: AppColors.point,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          elevation: 8,
          child: Obx(() {
            return Icon(
              isRecording.value ? Icons.stop : Icons.play_arrow,
              color: Colors.white,
              size: 50,
            );
          }),
        ),
      ),
    );
  }
}
