import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:csv/csv.dart';
// 新增1：导入多语言工具类（路径与home_screen/history_tab保持一致）
import '../../i18n/app_localizations.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _isScanning = false;
  bool _isConnected = false;
  bool _showOtherDevices = false;
  bool _isRecording = false;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _connectedDevice;
  // 数据记录相关变量
  List<List<dynamic>> _sensorData = [];
  Timer? _dataTimer;
  StreamSubscription<List<int>>? _dataSubscription;
  String _csvFilePath = '';

  @override
  void initState() {
    super.initState();
    _setupBluetoothListeners();
    _checkCurrentConnections();
    _requestPermissions();
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    // 请求存储权限
    if (await Permission.storage.isGranted == false) {
      await Permission.storage.request();
    }
    // 请求管理外部存储权限（Android 10+）
    if (await Permission.manageExternalStorage.isGranted == false) {
      await Permission.manageExternalStorage.request();
    }
  }

  void _checkCurrentConnections() async {
    try {
      List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
      if (connectedDevices.isNotEmpty) {
        setState(() {
          _isConnected = true;
          _connectedDevice = connectedDevices.first;
        });
        _startDataServices();
      }
    } catch (e) {
      print('Error checking current connections: $e');
    }
  }

  void _setupBluetoothListeners() {
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _devices = results.map((r) => r.device).toList();
      });
    });
    FlutterBluePlus.isScanning.listen((isScanning) {
      setState(() {
        _isScanning = isScanning;
      });
    });
    FlutterBluePlus.adapterState.listen((state) {
      print('Adapter state changed: $state');
      if (state == BluetoothAdapterState.off) {
        setState(() {
          _isConnected = false;
          _connectedDevice = null;
          _stopRecording();
        });
      }
    });
  }

  void _startScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      print('Scan error: $e');
    }
  }

  void _stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Stop scan error: $e');
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      await device.connect();
      if (Platform.isAndroid) {
        try {
          // 1. 请求大 MTU
          print("Requesting MTU 512...");
          await device.requestMtu(512);
          await Future.delayed(const Duration(milliseconds: 200));
          // 2. === 新增：请求高优先级连接 (Android 必需) ===
          // 这会将连接间隔从默认的 ~40ms 降低到 ~11ms，极大提高吞吐量，防止缓冲区堆积
          print("Requesting High Priority...");
          await device.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high);
          await Future.delayed(const Duration(milliseconds: 100)); // 再等一下让设置生效
        } catch (e) {
          print("Optimization failed: $e");
        }
      }
      setState(() {
        _isConnected = true;
        _connectedDevice = device;
      });
      _stopScan();
      // 连接后启动数据服务并开始记录
      _startDataServices();
      _startRecording();
      device.connectionState.listen((state) {
        print('Device connection state: $state');
        if (state == BluetoothConnectionState.disconnected) {
          setState(() {
            _isConnected = false;
            _connectedDevice = null;
            _stopRecording();
          });
        }
      });
    } catch (e) {
      print('Connection error: $e');
    }
  }

  void _disconnectDevice() async {
    try {
      await FlutterBluePlus.stopScan();
      _stopRecording();
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      setState(() {
        _isConnected = false;
        _connectedDevice = null;
        _devices.clear();
      });
    } catch (e) {
      print('Disconnect error: $e');
    }
  }

  // 启动数据服务
  void _startDataServices() async {
    if (_connectedDevice == null) return;
    try {
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      String targetServiceUuid = "ac53c60f-179a-40f9-a1e1-abe320dc8e41";
      String targetCharacteristicUuid = "3631478e-0a3a-4ccc-8f37-76b12db44564";
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == targetServiceUuid.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == targetCharacteristicUuid.toLowerCase()) {
              await characteristic.setNotifyValue(true);
              _dataSubscription = characteristic.onValueReceived.listen((value) {
                _handleSensorData(value);
              });
              print("成功订阅传感器数据");
              return;
            }
          }
        }
      }
      print("未找到目标服务或特征值");
      // 调试信息
      print("可用的服务:");
      for (BluetoothService service in services) {
        print("服务 UUID: ${service.uuid}");
        for (BluetoothCharacteristic char in service.characteristics) {
          print("  - 特征 UUID: ${char.uuid}, 属性: ${char.properties}");
        }
      }
    } catch (e) {
      print("启动数据服务错误: $e");
    }
  }

  // 处理传感器数据 - 根据Zephyr代码的数据格式进行解析
  void _handleSensorData(List<int> data) {
    if (data.isEmpty) return;
    DateTime timestamp = DateTime.now();
    try {
      // 根据Zephyr代码，数据格式为：
      // 1字节: 样本计数 (count)
      // 随后是 count * 24字节: 每个样本包含6个float (加速度xyz + 陀螺仪xyz)
      ByteData byteData = ByteData.sublistView(Uint8List.fromList(data));
      int offset = 0;
      // 读取样本计数
      int sampleCount = byteData.getUint8(offset);
      offset += 1;
      // 验证数据长度
      int expectedLength = 1 + sampleCount * 24; // 1字节计数 + 样本数 * 24字节
      if (data.length != expectedLength) {
        print("数据长度不匹配: 期望 $expectedLength, 实际 ${data.length}");
        return;
      }
      // 解析每个样本
      for (int i = 0; i < sampleCount; i++) {
        // 读取加速度数据 (3个float)
        double accelX = byteData.getFloat32(offset, Endian.little);
        offset += 4;
        double accelY = byteData.getFloat32(offset, Endian.little);
        offset += 4;
        double accelZ = byteData.getFloat32(offset, Endian.little);
        offset += 4;
        // 读取陀螺仪数据 (3个float)
        double gyroX = byteData.getFloat32(offset, Endian.little);
        offset += 4;
        double gyroY = byteData.getFloat32(offset, Endian.little);
        offset += 4;
        double gyroZ = byteData.getFloat32(offset, Endian.little);
        offset += 4;
        // 添加到数据列表
        _sensorData.add([
          timestamp.toIso8601String(),
          accelX.toStringAsFixed(6),
          accelY.toStringAsFixed(6),
          accelZ.toStringAsFixed(6),
          gyroX.toStringAsFixed(6),
          gyroY.toStringAsFixed(6),
          gyroZ.toStringAsFixed(6),
        ]);
      }
      print("成功解析 $sampleCount 个传感器样本");
    } catch (e) {
      print("解析传感器数据错误: $e");
      // 如果解析失败，至少保存原始数据
      String dataString = String.fromCharCodes(data);
      _sensorData.add([
        timestamp.toIso8601String(),
        dataString,
        '解析错误',
        '解析错误',
        '解析错误',
        '解析错误',
        '解析错误',
      ]);
    }
    setState(() {});
  }

  // 开始记录数据 - 自动开始，不显示控制界面
  void _startRecording() async {
    if (_isRecording) return;
    setState(() {
      _isRecording = true;
      _sensorData.clear();
    });
    // 添加CSV表头
    _sensorData.add([
      'Timestamp',
      'Acceleration_X',
      'Acceleration_Y',
      'Acceleration_Z',
      'Gyro_X',
      'Gyro_Y',
      'Gyro_Z'
    ]);
    // 创建CSV文件 - 保存到Download目录
    String downloadPath = '/storage/emulated/0/Download';
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    _csvFilePath = '$downloadPath/sensor_data_$timestamp.csv';
    // 确保目录存在
    Directory downloadDir = Directory(downloadPath);
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    // 定时保存数据到文件
    _dataTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _saveDataToCsv();
    });
    print("开始自动记录数据到: $_csvFilePath");
  }

  // 停止记录数据
  void _stopRecording() {
    if (!_isRecording) return;
    _dataTimer?.cancel();
    _dataTimer = null;
    _saveDataToCsv();
    setState(() {
      _isRecording = false;
    });
    print("停止记录数据，文件保存在: $_csvFilePath");
    // 显示保存成功的提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('数据已保存到: $_csvFilePath'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 保存数据到CSV文件
  void _saveDataToCsv() async {
    if (_sensorData.isEmpty) return;
    try {
      String csvData = const ListToCsvConverter().convert(_sensorData);
      File file = File(_csvFilePath);
      await file.writeAsString(csvData);
      print("数据已保存到CSV文件，当前数据点: ${_sensorData.length}");
    } catch (e) {
      print("保存CSV文件错误: $e");
    }
  }

  void _goBack() {
    setState(() {
      _stopScan();
      _devices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 新增2：获取多语言实例（仅添加这一行）
    final loc = AppLocalizations.of(context);
    // 原有代码：传递loc到_buildBody
    return _buildBody(loc);
  }

  // 新增3：_buildBody方法添加loc参数
  Widget _buildBody(AppLocalizations loc) {
    if (_isConnected) {
      // 传递loc到_buildConnectedState
      return _buildConnectedState(loc);
    } else {
      // 传递loc到_buildDisconnectedState
      return _buildDisconnectedState(loc);
    }
  }

  // 新增4：_buildDisconnectedState方法添加loc参数
  Widget _buildDisconnectedState(AppLocalizations loc) {
    List<BluetoothDevice> myFitnessPodDevices = _devices.where((device) {
      String name = device.platformName;
      return name.isNotEmpty && name.toLowerCase().contains("myfitnesspod");
    }).toList();
    List<BluetoothDevice> otherDevices = _devices.where((device) {
      String name = device.platformName;
      return name.isEmpty || !name.toLowerCase().contains("myfitnesspod");
    }).toList();
    if (_devices.isNotEmpty) {
      // 传递loc到_buildDeviceListState
      return _buildDeviceListState(loc, myFitnessPodDevices, otherDevices);
    } else {
      // 传递loc到_buildSearchState
      return _buildSearchState(loc);
    }
  }

  // 新增5：_buildSearchState方法添加loc参数，替换固定文本
  Widget _buildSearchState(AppLocalizations loc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: GestureDetector(
            onTap: _isScanning ? _stopScan : _startScan,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/Search.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 20),
                // 替换：Scanning... / Search devices
                Text(
                  _isScanning ? loc.translate('scanning') : loc.translate('searchDevices'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 新增6：_buildDeviceListState方法添加loc参数
  Widget _buildDeviceListState(AppLocalizations loc, List<BluetoothDevice> myFitnessPodDevices, List<BluetoothDevice> otherDevices) {
    return Column(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 16.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goBack,
              // 替换：Back to search
              tooltip: loc.translate('backToSearch'),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              if (myFitnessPodDevices.isNotEmpty)
                // 传递loc到_buildDeviceSection，替换title
                _buildDeviceSection(
                  loc: loc,
                  title: loc.translate('myFitnessPod'),
                  devices: myFitnessPodDevices,
                  icon: Icons.fitness_center,
                  iconColor: Colors.blue,
                ),
              if (otherDevices.isNotEmpty)
                // 传递loc到_buildOtherDevicesSection
                _buildOtherDevicesSection(loc, otherDevices),
              if (myFitnessPodDevices.isEmpty && otherDevices.isEmpty)
                Expanded(
                  child: Center(
                    // 替换：No devices found
                    child: Text(
                      loc.translate('noDevicesFound'),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 新增7：_buildDeviceSection方法添加loc参数，替换Connect按钮
  Widget _buildDeviceSection({
    required AppLocalizations loc, // 新增loc参数
    required String title,
    required List<BluetoothDevice> devices,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                title: Text(
                  device.platformName.isEmpty ? title : device.platformName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(device.remoteId.str),
                trailing: ElevatedButton(
                  onPressed: () => _connectToDevice(device),
                  // 替换：Connect
                  child: Text(loc.translate('connect')),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 新增8：_buildOtherDevicesSection方法添加loc参数，替换固定文本
  Widget _buildOtherDevicesSection(AppLocalizations loc, List<BluetoothDevice> otherDevices) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: ExpansionTile(
        // 只保留左边的箭头，移除右边的箭头
        trailing: const SizedBox.shrink(), // 这将移除右边的箭头
        leading: Icon(
          _showOtherDevices ? Icons.expand_more : Icons.chevron_right,
          color: Colors.grey,
        ),
        // 替换：Other Devices
        title: Text(
          loc.translate('otherDevices'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        initiallyExpanded: false,
        onExpansionChanged: (expanded) {
          setState(() {
            _showOtherDevices = expanded;
          });
        },
        children: [
          // 限制列表高度，允许滚动
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4, // 限制最大高度
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(), // 使用ClampingScrollPhysics允许滚动
              itemCount: otherDevices.length,
              itemBuilder: (context, index) {
                final device = otherDevices[index];
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  // 替换：Unknown Device
                  title: Text(device.platformName.isEmpty ? loc.translate('unknownDevice') : device.platformName),
                  subtitle: Text(device.remoteId.str),
                  trailing: ElevatedButton(
                    onPressed: () => _connectToDevice(device),
                    // 替换：Connect
                    child: Text(loc.translate('connect')),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 新增9：_buildConnectedState方法添加loc参数，替换固定文本
  Widget _buildConnectedState(AppLocalizations loc) {
    // 移除数据记录控制区域，保持原来的界面
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 替换：Device connected
              Text(
                loc.translate('deviceConnected'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              // 替换：Exercise Identifying...
              Text(
                loc.translate('exerciseIdentifying'),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Image.asset(
                'assets/images/Identify.png',
                width: 120,
                height: 120,
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: ElevatedButton(
            onPressed: _disconnectDevice,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            // 替换：Disconnect
            child: Text(
              loc.translate('disconnect'),
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}