import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:csv/csv.dart';
import '../../i18n/app_localizations.dart';

// 导入滤波器和计数器工具类（请根据实际路径调整）
import '../../utils/low_pass_filter.dart';
import '../../utils/squat_counter.dart';
import '../../utils/bicepcurl_counter.dart' as bc;

// === 将枚举定义移到顶层 ===
enum ConnectedSubState { waiting, showingExercise, showingSummary }

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // === 原有监听器变量 ===
  StreamSubscription? _scanResultsSubscription;
  StreamSubscription? _isScanningSubscription;
  StreamSubscription? _adapterStateSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
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
  DateTime _recordingStartTime = DateTime.now();
  int _totalSamplesReceived = 0;
  double _sampleIntervalMs = 1000.0 / 104.0;
  bool _isConnecting = false;

  // === 连接后UI子状态 ===
  ConnectedSubState _connectedSubState = ConnectedSubState.waiting;
  String? _currentExercise;
  String? _currentExerciseImage;
  int? _exerciseCount;
  bool _hasDetectedExercise = false;
  Timer? _summaryTimer;

  // === 断开连接时消息界面 ===
  bool _showDisconnectMessage = false;
  String _disconnectMessage = '';
  Timer? _disconnectTimer;

  // === 滤波器与计数器实例 ===
  FirstOrderLowPassFilter? _filter;
  SquatCounter? _squatCounter;
  bc.ExerciseCounter? _bicepCurlCounter;
  dynamic _activeCounter; // 当前激活的计数器

  @override
  void initState() {
    super.initState();
    _setupBluetoothListeners();
    _checkCurrentConnections();
    _requestPermissions();
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _dataTimer?.cancel();
    _dataSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _summaryTimer?.cancel();
    _disconnectTimer?.cancel();
    super.dispose();
  }

  // ==================== 辅助方法 ====================
  void _resetFiltersAndCounters() {
    _filter = FirstOrderLowPassFilter(cutoff: 5.0, fs: 104.0);
    _squatCounter = SquatCounter();
    _bicepCurlCounter = bc.ExerciseCounter();
    _activeCounter = null;
  }

  void _setActiveCounter(String exerciseName) {
    switch (exerciseName.toLowerCase()) {
      case 'squat':
        _activeCounter = _squatCounter;
        break;
      case 'bicep curl':
        _activeCounter = _bicepCurlCounter;
        break;
      default:
        _activeCounter = null;
    }
    _activeCounter?.resetCount();
  }

  void _resetAllState() {
    _filter = null;
    _squatCounter = null;
    _bicepCurlCounter = null;
    _activeCounter = null;
    _connectedSubState = ConnectedSubState.waiting;
    _currentExercise = null;
    _currentExerciseImage = null;
    _exerciseCount = null;
    _hasDetectedExercise = false;
    _showDisconnectMessage = false;
    _disconnectMessage = '';
    _summaryTimer?.cancel();
    _summaryTimer = null;
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
  }

  // ==================== 原有方法 ====================
  Future<void> _requestPermissions() async {
    if (await Permission.storage.isGranted == false) {
      await Permission.storage.request();
    }
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
        _resetFiltersAndCounters();
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
        _resetAllState();
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
    if (_isConnecting) return;
    if (mounted) setState(() => _isConnecting = true);

    try {
      await FlutterBluePlus.stopScan();
      if (_connectedDevice != null && _connectedDevice != device) {
        await _connectedDevice!.disconnect();
      }
      await device.connect(autoConnect: false);

      if (Platform.isAndroid) {
        try {
          print("Requesting MTU 512...");
          await device.requestMtu(512);
          await Future.delayed(const Duration(milliseconds: 200));
          print("Requesting High Priority...");
          await device.requestConnectionPriority(connectionPriorityRequest: ConnectionPriority.high);
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print("Optimization failed: $e");
        }
      }

      _resetFiltersAndCounters();

      if (mounted) {
        setState(() {
          _isConnected = true;
          _connectedDevice = device;
        });
      }

      _setupConnectionStateListener(device);
      _startDataServices();
      _startRecording();

    } catch (e) {
      print('Connection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
        setState(() {
          _isConnected = false;
          _connectedDevice = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _setupConnectionStateListener(BluetoothDevice device) {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = device.connectionState.listen((state) {
      print('Device connection state: $state');
      if (state == BluetoothConnectionState.disconnected) {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _connectedDevice = null;
          });
        }
        _stopRecording();
        _dataSubscription?.cancel();
        _dataSubscription = null;
        _resetAllState();
      }
    });
  }

  void _disconnectDevice() {
    if (_showDisconnectMessage) return;
    _summaryTimer?.cancel();
    _summaryTimer = null;

    setState(() {
      _showDisconnectMessage = true;
      _disconnectMessage = _hasDetectedExercise
          ? 'Exercises have been recorded'
          : 'No exercise detected';
    });

    _disconnectTimer?.cancel();
    _disconnectTimer = Timer(const Duration(seconds: 3), () {
      _performDisconnect();
    });
  }

  Future<void> _performDisconnect() async {
    try {
      await FlutterBluePlus.stopScan();
      _stopRecording();
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
    } catch (e) {
      print('Disconnect error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _connectedDevice = null;
          _devices.clear();
          _resetAllState();
        });
      }
      _disconnectTimer = null;
    }
  }

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
              await _dataSubscription?.cancel();
              _dataSubscription = null;
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

  void _handleSensorData(List<int> data) {
    if (data.isEmpty) return;

    try {
      ByteData byteData = ByteData.sublistView(Uint8List.fromList(data));
      int offset = 0;

      int sampleCount = byteData.getUint8(offset);
      offset += 1;

      int expectedLength = 1 + sampleCount * 24;
      if (data.length != expectedLength) {
        print("数据长度不匹配: 期望 $expectedLength, 实际 ${data.length}");
        return;
      }

      for (int i = 0; i < sampleCount; i++) {
        int sampleOffsetMs = (_totalSamplesReceived * _sampleIntervalMs).round();
        DateTime sampleTime = _recordingStartTime.add(Duration(milliseconds: sampleOffsetMs));

        double accelX = byteData.getFloat32(offset, Endian.little);
        offset += 4;
        double accelY = byteData.getFloat32(offset, Endian.little);
        offset += 4;
        double accelZ = byteData.getFloat32(offset, Endian.little);
        offset += 4;

        double gyroX = byteData.getFloat32(offset, Endian.little);
        offset += 4;
        double gyroY = byteData.getFloat32(offset, Endian.little);
        offset += 4;
        double gyroZ = byteData.getFloat32(offset, Endian.little);
        offset += 4;

        // 对 Z 轴加速度进行滤波
        _filter ??= FirstOrderLowPassFilter();
        double filteredZ = _filter!.filterSingle(accelZ, 'z');

        // 如果当前有激活的计数器，传入滤波后的值进行计数
        if (_activeCounter != null) {
          if (_activeCounter is SquatCounter) {
            (_activeCounter as SquatCounter).countBySingleAxis(filteredZ);
          } else if (_activeCounter is bc.ExerciseCounter) {
            (_activeCounter as bc.ExerciseCounter).countBySingleAxis(filteredZ);
          }
        }

        // 保存原始数据到 CSV
        _sensorData.add([
          sampleTime.toIso8601String(),
          accelX.toStringAsFixed(6),
          accelY.toStringAsFixed(6),
          accelZ.toStringAsFixed(6),
          gyroX.toStringAsFixed(6),
          gyroY.toStringAsFixed(6),
          gyroZ.toStringAsFixed(6),
        ]);

        _totalSamplesReceived++;
      }

      print("成功解析 $sampleCount 个传感器样本，总样本数: $_totalSamplesReceived");

    } catch (e) {
      print("解析传感器数据错误: $e");
      String dataString = String.fromCharCodes(data);
      _sensorData.add([
        DateTime.now().toIso8601String(),
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

  void _startRecording() async {
    if (_isRecording) return;

    setState(() {
      _isRecording = true;
      _sensorData.clear();
      _totalSamplesReceived = 0;
      _recordingStartTime = DateTime.now();
    });

    _sensorData.add([
      'Timestamp',
      'Acceleration_X',
      'Acceleration_Y',
      'Acceleration_Z',
      'Gyro_X',
      'Gyro_Y',
      'Gyro_Z'
    ]);

    String dirPath;
    try {
      if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        dirPath = directory.path;
      } else {
        dirPath = '/storage/emulated/0/Download';
      }

      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      _csvFilePath = '$dirPath/sensor_data_$timestamp.csv';

      Directory targetDir = Directory(dirPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      _dataTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _saveDataToCsv();
      });

      print("开始自动记录数据到: $_csvFilePath");
      print("记录起始时间: $_recordingStartTime");

    } catch (e) {
      print("获取存储路径失败: $e");
      setState(() {
        _isRecording = false;
      });
    }
  }

  void _stopRecording() {
    if (!_isRecording) return;
    _dataTimer?.cancel();
    _dataTimer = null;
    _saveDataToCsv();
    setState(() {
      _isRecording = false;
      _totalSamplesReceived = 0;
    });
    print("停止记录数据，文件保存在: $_csvFilePath");
    print("总记录样本数: $_totalSamplesReceived");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('数据已保存到: $_csvFilePath'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

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

  // ==================== 预留运动检测接口 ====================
  void _onExerciseDetected(String exerciseName) {
    String imagePath;
    switch (exerciseName.toLowerCase()) {
      case 'bicep curl':
        imagePath = 'assets/images/bicepcurl.png';
        break;
      case 'bench press':
        imagePath = 'assets/images/Bench press.png';
        break;
      case 'running':
        imagePath = 'assets/images/Running.png';
        break;
      case 'sit-up':
        imagePath = 'assets/images/Sit-up.png';
        break;
      case 'squat':
        imagePath = 'assets/images/Squat.png';
        break;
      default:
        imagePath = 'assets/images/Identify.png';
    }

    _setActiveCounter(exerciseName);

    setState(() {
      _currentExercise = exerciseName;
      _currentExerciseImage = imagePath;
      _connectedSubState = ConnectedSubState.showingExercise;
      _hasDetectedExercise = true;
    });

    _summaryTimer?.cancel();
    _summaryTimer = null;
  }

  void _onExerciseStopped() {
    int count = 0;
    if (_activeCounter != null) {
      if (_activeCounter is SquatCounter) {
        count = (_activeCounter as SquatCounter).count;
      } else if (_activeCounter is bc.ExerciseCounter) {
        count = (_activeCounter as bc.ExerciseCounter).count;
      }
    }

    setState(() {
      _exerciseCount = count;
      _connectedSubState = ConnectedSubState.showingSummary;
    });

    _summaryTimer?.cancel();
    _summaryTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _connectedSubState = ConnectedSubState.waiting;
          _currentExercise = null;
          _currentExerciseImage = null;
          _exerciseCount = null;
        });
      }
    });
  }
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return _buildBody(loc);
  }

  Widget _buildBody(AppLocalizations loc) {
    if (_showDisconnectMessage) {
      return _buildDisconnectMessage(loc);
    }
    if (_isConnected) {
      return _buildConnectedState(loc);
    } else {
      return _buildDisconnectedState(loc);
    }
  }

  Widget _buildDisconnectMessage(AppLocalizations loc) {
    return Center(
      child: Text(
        _disconnectMessage,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildConnectedState(AppLocalizations loc) {
    switch (_connectedSubState) {
      case ConnectedSubState.waiting:
        return _buildWaitingState(loc);
      case ConnectedSubState.showingExercise:
        return _buildExerciseDisplayState(loc);
      case ConnectedSubState.showingSummary:
        return _buildSummaryState(loc);
    }
  }

  Widget _buildWaitingState(AppLocalizations loc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                loc.translate('deviceConnected'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
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
            child: Text(
              loc.translate('disconnect'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseDisplayState(AppLocalizations loc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_currentExercise != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              _currentExercise!,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (_currentExerciseImage != null)
          Image.asset(
            _currentExerciseImage!,
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _disconnectDevice,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: Text(
            loc.translate('disconnect'),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryState(AppLocalizations loc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Image.asset(
                _currentExerciseImage ?? 'assets/images/Identify.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentExercise ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${loc.translate('repetitions')}: ${_exerciseCount ?? 0}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _disconnectDevice,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: Text(
            loc.translate('disconnect'),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

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
      return _buildDeviceListState(loc, myFitnessPodDevices, otherDevices);
    } else {
      return _buildSearchState(loc);
    }
  }

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
              tooltip: loc.translate('backToSearch'),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              if (myFitnessPodDevices.isNotEmpty)
                _buildDeviceSection(
                  loc: loc,
                  title: loc.translate('myFitnessPod'),
                  devices: myFitnessPodDevices,
                  icon: Icons.fitness_center,
                  iconColor: Colors.blue,
                ),
              if (otherDevices.isNotEmpty)
                _buildOtherDevicesSection(loc, otherDevices),
              if (myFitnessPodDevices.isEmpty && otherDevices.isEmpty)
                Expanded(
                  child: Center(
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

  Widget _buildDeviceSection({
    required AppLocalizations loc,
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
                  child: Text(loc.translate('connect')),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOtherDevicesSection(AppLocalizations loc, List<BluetoothDevice> otherDevices) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: ExpansionTile(
        trailing: const SizedBox.shrink(),
        leading: Icon(
          _showOtherDevices ? Icons.expand_more : Icons.chevron_right,
          color: Colors.grey,
        ),
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
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: otherDevices.length,
              itemBuilder: (context, index) {
                final device = otherDevices[index];
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(device.platformName.isEmpty ? loc.translate('unknownDevice') : device.platformName),
                  subtitle: Text(device.remoteId.str),
                  trailing: ElevatedButton(
                    onPressed: () => _connectToDevice(device),
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
}