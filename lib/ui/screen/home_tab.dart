import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:csv/csv.dart';
import '../../i18n/app_localizations.dart';
import 'dart:math' as math;
// 导入二头弯举计数器（仍保留）
import '../../utils/bicepcurl_counter.dart' as bc;

// 导入 TensorFlow Lite 解释器
import 'package:tflite_flutter/tflite_flutter.dart';

// 导入历史记录提供者
import 'package:provider/provider.dart';
import '../../providers/history_provider.dart';

// 连接后UI子状态枚举
enum ConnectedSubState { waiting, showingExercise, showingSummary }

// ==================== 移动平均滤波器（三点平均） ====================
class _MovingAverageFilter {
  final List<double> _buffer = [];
  final int _windowSize = 3;

  double filter(double newValue) {
    _buffer.add(newValue);
    if (_buffer.length > _windowSize) {
      _buffer.removeAt(0);
    }
    if (_buffer.length < _windowSize) {
      return newValue;
    }
    return _buffer.reduce((a, b) => a + b) / _windowSize;
  }

  void reset() {
    _buffer.clear();
  }
}

class _ButterworthFilter {
  static const int _numChannels = 6;
  final List<double> _b = [4.82434303e-05, 1.92973721e-04, 2.89460582e-04, 1.92973721e-04, 4.82434303e-05];
  final List<double> _a = [1.0, -3.45322477, 4.50413095, -2.62779547, 0.57714418];

  late List<List<double>> _x;
  late List<List<double>> _y;

  _ButterworthFilter() {
    _x = List.generate(_numChannels, (_) => List.filled(5, 0.0));
    _y = List.generate(_numChannels, (_) => List.filled(5, 0.0));
  }

  List<double> filter(List<double> input) {
    List<double> output = List.filled(_numChannels, 0.0);

    for (int c = 0; c < _numChannels; c++) {
      for (int i = 4; i > 0; i--) _x[c][i] = _x[c][i - 1];
      _x[c][0] = input[c];

      double out = _b[0] * _x[c][0];
      for (int i = 1; i <= 4; i++) {
        out += _b[i] * _x[c][i] - _a[i] * _y[c][i];
      }

      for (int i = 4; i > 1; i--) _y[c][i] = _y[c][i - 1];
      _y[c][1] = out;
      output[c] = out;
    }
    return output;
  }
}

// ==================== 蹲起计数器（使用原始Z轴，阈值4.0） ====================
class _SquatCounter {
  int _count = 0;
  bool _isInSquat = false;
  final double threshold = 6.5; // 可根据实际信号调整

  int get count => _count;

  void addSample(double rawValue) {
    // 可取消注释以观察原始值
    // print('原始 Z: $rawValue, 状态: $_isInSquat');
    if (rawValue < threshold && !_isInSquat) {
      _isInSquat = true;
    } else if (rawValue > threshold && _isInSquat) {
      _count++;
      print('✅ 蹲起计数 +1，当前总数: $_count');
      _isInSquat = false;
    }
  }

  void reset() {
    _count = 0;
    _isInSquat = false;
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // ==================== 蓝牙相关变量 ====================
  StreamSubscription? _scanResultsSubscription;
  _ButterworthFilter? _imuFilter;
  StreamSubscription? _isScanningSubscription;
  StreamSubscription? _adapterStateSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  bool _isScanning = false;
  bool _isConnected = false;
  bool _showOtherDevices = false;
  bool _isRecording = false;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _connectedDevice;
  List<List<dynamic>> _sensorData = [];
  Timer? _dataTimer;
  StreamSubscription<List<int>>? _dataSubscription;
  String _csvFilePath = '';
  DateTime _recordingStartTime = DateTime.now();
  int _totalSamplesReceived = 0;
  double _sampleIntervalMs = 1000.0 / 104.0;
  bool _isConnecting = false;

  // ==================== UI状态变量 ====================
  ConnectedSubState _connectedSubState = ConnectedSubState.waiting;
  String? _currentExercise;
  String? _currentExerciseImage;
  int? _exerciseCount;
  bool _hasDetectedExercise = false;
  Timer? _summaryTimer;
  bool _showDisconnectMessage = false;
  String _disconnectMessage = '';
  Timer? _disconnectTimer;

  // ==================== 滤波与计数器 ====================
  _MovingAverageFilter? _filter;
  _SquatCounter? _squatCounter;
  bc.ExerciseCounter? _bicepCurlCounter;
  dynamic _activeCounter; // 当前激活的计数器

  // ==================== TFLite 模型相关 ====================
  Interpreter? _interpreter;
  List<String> _labels = [];
  List<List<double>> _sensorWindow = [];
  final int _windowSize = 208;
  final int _inferenceInterval = 10;
  int _sampleCounterForInference = 0;

  String? _currentInferredExercise;
  int _stableCount = 0;
  final int _stableThreshold = 5;
  final double _confidenceThreshold = 0.7;

  // ==================== 历史记录相关 ====================
  List<ExerciseSet> _sessionExercises = [];
  String? _currentExerciseName;

  // ==================== 初始化与销毁 ====================
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
    _interpreter?.close();
    super.dispose();
  }

  // ==================== 辅助方法 ====================
  void _resetFiltersAndCounters() {
    _filter = _MovingAverageFilter();
    _squatCounter = _SquatCounter();
    _bicepCurlCounter = bc.ExerciseCounter();
    _activeCounter = null;
    _imuFilter = _ButterworthFilter();
  }

  void _setActiveCounter(String exerciseName) {
    switch (exerciseName.toLowerCase()) {
      case 'squat':
        _activeCounter = _squatCounter;
        break;
      case 'bicep':
        _activeCounter = _bicepCurlCounter;
        break;
      default:
        _activeCounter = null;
    }
    _activeCounter?.reset();
  }

  int _getCurrentCount() {
    if (_activeCounter == null) return 0;
    if (_activeCounter is _SquatCounter) {
      return (_activeCounter as _SquatCounter).count;
    } else if (_activeCounter is bc.ExerciseCounter) {
      return (_activeCounter as bc.ExerciseCounter).count;
    }
    return 0;
  }

  void _resetAllState() {
    _filter = null;
    _squatCounter = null;
    _bicepCurlCounter = null;
    _activeCounter = null;
    _imuFilter = null;
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

    _sensorWindow.clear();
    _sampleCounterForInference = 0;
    _currentInferredExercise = null;
    _stableCount = 0;

    _sessionExercises.clear();
    _currentExerciseName = null;
  }

  // ==================== 模型加载 ====================
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/miniresnet_model.tflite');
      print('✅ 模型加载成功');
      var inputTensors = _interpreter!.getInputTensors();
      print('模型输入张量: $inputTensors');
      _labels = ['rest', 'squat', 'bicep'];
    } catch (e) {
      print('❌ 模型加载失败: $e');
    }
  }

  static const List<double> _bCoeffs = [4.82434303e-05, 1.92973721e-04, 2.89460582e-04, 1.92973721e-04, 4.82434303e-05];
  static const List<double> _aCoeffs = [1.0, -3.45322477, 4.50413095, -2.62779547, 0.57714418];
  List<double>? _cachedZi;

  List<double> _lfilterDF2T(List<double> x, [List<double>? zi]) {
    int n = x.length;
    List<double> y = List.filled(n, 0.0);
    List<double> z = zi != null ? List.from(zi) : List.filled(4, 0.0);

    for (int i = 0; i < n; i++) {
      y[i] = _bCoeffs[0] * x[i] + z[0];
      z[0] = _bCoeffs[1] * x[i] - _aCoeffs[1] * y[i] + z[1];
      z[1] = _bCoeffs[2] * x[i] - _aCoeffs[2] * y[i] + z[2];
      z[2] = _bCoeffs[3] * x[i] - _aCoeffs[3] * y[i] + z[3];
      z[3] = _bCoeffs[4] * x[i] - _aCoeffs[4] * y[i];
    }
    return y;
  }

  List<double> _computeZi() {
    if (_cachedZi != null) return _cachedZi!;
    List<double> z = List.filled(4, 0.0);
    for (int i = 0; i < 2000; i++) {
      double yi = _bCoeffs[0] * 1.0 + z[0];
      z[0] = _bCoeffs[1] * 1.0 - _aCoeffs[1] * yi + z[1];
      z[1] = _bCoeffs[2] * 1.0 - _aCoeffs[2] * yi + z[2];
      z[2] = _bCoeffs[3] * 1.0 - _aCoeffs[3] * yi + z[3];
      z[3] = _bCoeffs[4] * 1.0 - _aCoeffs[4] * yi;
    }
    _cachedZi = z;
    return z;
  }

  List<List<double>> _filtfilt(List<List<double>> window) {
    int len = window.length;
    int padLen = 14;
    List<double> zi = _computeZi();
    List<List<double>> result = List.generate(len, (_) => List.filled(6, 0.0));

    for (int c = 0; c < 6; c++) {
      List<double> col = List.generate(len, (i) => window[i][c]);

      List<double> padded = List.filled(padLen + len + padLen, 0.0);
      for (int i = 0; i < padLen; i++) {
        padded[padLen - 1 - i] = 2 * col[0] - col[i + 1];
      }
      for (int i = 0; i < len; i++) {
        padded[padLen + i] = col[i];
      }
      for (int i = 0; i < padLen; i++) {
        padded[padLen + len + i] = 2 * col[len - 1] - col[len - 2 - i];
      }

      List<double> ziF = zi.map((z) => z * padded[0]).toList();
      List<double> forward = _lfilterDF2T(padded, ziF);

      List<double> rev = forward.reversed.toList();
      List<double> ziB = zi.map((z) => z * rev[0]).toList();
      List<double> backward = _lfilterDF2T(rev, ziB);

      List<double> final_ = backward.reversed.toList();
      for (int i = 0; i < len; i++) {
        result[i][c] = final_[padLen + i];
      }
    }
    return result;
  }

  // ==================== 运动推理 ====================
  void _runInference() {
    if (_interpreter == null) return;
    if (_sensorWindow.length < _windowSize) return;

    try {
      List<List<double>> filtered = _filtfilt(_sensorWindow);

      List<double> flatten = [];
      for (var sample in _sensorWindow) {
        flatten.addAll(sample);
      }
      Float32List input = Float32List.fromList(flatten);

      var output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);

      _interpreter!.run(input, output);

      List<double> probabilities = output[0] as List<double>;
      int maxIndex = 0;
      double maxProb = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      String detectedExercise = _labels[maxIndex];
      print('📊 推理: $detectedExercise, 置信度: ${maxProb.toStringAsFixed(3)}, 稳定计数: $_stableCount');

      if (maxProb > _confidenceThreshold) {
        if (_currentInferredExercise == detectedExercise) {
          _stableCount++;
        } else {
          _currentInferredExercise = detectedExercise;
          _stableCount = 1;
        }

        if (_stableCount >= _stableThreshold && _connectedSubState == ConnectedSubState.waiting && detectedExercise != 'rest') {
          print('🎯 动作转换: waiting → $detectedExercise');
          _onExerciseDetected(detectedExercise);
        }

        if (_stableCount >= _stableThreshold &&
            _connectedSubState == ConnectedSubState.showingExercise &&
            detectedExercise == 'rest') {
          print('🏁 动作转换: $_currentExercise → rest');
          _onExerciseStopped();
        }

        if (_stableCount >= _stableThreshold &&
            _connectedSubState == ConnectedSubState.showingExercise &&
            detectedExercise != 'rest' &&
            detectedExercise != _currentExercise) {
          print('🔄 动作直接切换: $_currentExercise → $detectedExercise');
          _onExerciseStopped();       // 先结算当前运动
          _onExerciseDetected(detectedExercise);  // 再开始新运动
        }

// summary 期间检测到新运动，立即切换
        if (_stableCount >= _stableThreshold &&
            _connectedSubState == ConnectedSubState.showingSummary &&
            detectedExercise != 'rest') {
          print('⚡ Summary 期间检测到新动作: $detectedExercise');
          _summaryTimer?.cancel();
          _onExerciseDetected(detectedExercise);
        }
      } else {
        _stableCount = 0;
        _currentInferredExercise = null;
      }
    } catch (e) {
      print('推理内部错误: $e');
    }
  }

  // ==================== 蓝牙相关方法 ====================
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
        _loadModel();
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
      _loadModel();

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
      _performDisconnect(context);
    });
  }

  Future<void> _performDisconnect(BuildContext context) async {
    if (_currentExerciseName != null && _activeCounter != null) {
      int count = _getCurrentCount();
      if (count > 0) {
        _sessionExercises.add(ExerciseSet(
          exerciseName: _currentExerciseName!,
          reps: count,
          sets: 1,
        ));
      }
      _currentExerciseName = null;
      _activeCounter?.reset();
    }

    if (_sessionExercises.isNotEmpty) {
      final history = Provider.of<HistoryProvider>(context, listen: false);
      history.addSession(WorkoutSession(
        date: DateTime.now(),
        exercises: List.from(_sessionExercises),
      ));
      _sessionExercises.clear();
    }

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
    } catch (e) {
      print("启动数据服务错误: $e");
    }
  }

  // ==================== 数据处理（关键修改：计数器使用原始 Z 轴） ====================
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

      _imuFilter ??= _ButterworthFilter();

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

        // 滤波（用于显示或后续处理）
        List<double> rawSample = [accelX, accelY, accelZ, gyroX, gyroY, gyroZ];
        List<double> filteredSample = _imuFilter!.filter(rawSample);

        // 计数逻辑：使用原始 Z 轴 (accelZ)，不经过滤波，阈值已在 _SquatCounter 内部处理
        if (_activeCounter != null) {
          if (_activeCounter is _SquatCounter) {
            (_activeCounter as _SquatCounter).addSample(accelZ); // 使用原始值
          } else if (_activeCounter is bc.ExerciseCounter) {
            (_activeCounter as bc.ExerciseCounter).countBySingleAxis(accelZ); // 假设也使用原始值
          }
        }

        // 滑动窗口存原始数据，用于推理
        _sensorWindow.add([accelX, accelY, accelZ, gyroX, gyroY, gyroZ]);
        if (_sensorWindow.length > _windowSize) {
          _sensorWindow.removeAt(0);
        }

        _sampleCounterForInference++;
        if (_sampleCounterForInference >= _inferenceInterval && _sensorWindow.length == _windowSize) {
          _sampleCounterForInference = 0;
          try {
            _runInference();
          } catch (e) {
            print('推理异常: $e');
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

    } catch (e) {
      print("解析传感器数据错误: $e");
    }
    setState(() {});
  }

  // ==================== 记录与保存 ====================
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

  // ==================== 运动检测接口 ====================
  void _onExerciseDetected(String exerciseName) {
    if (_currentExerciseName != null && _activeCounter != null) {
      int count = _getCurrentCount();
      if (count > 0) {
        _sessionExercises.add(ExerciseSet(
          exerciseName: _currentExerciseName!,
          reps: count,
          sets: 1,
        ));
      }
    }

    _setActiveCounter(exerciseName);
    _activeCounter?.reset();
    _currentExerciseName = exerciseName;

    String imagePath;
    switch (exerciseName.toLowerCase()) {
      case 'bicep':
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
    int lastCount = 0;
    if (_currentExerciseName != null && _activeCounter != null) {
      lastCount = _getCurrentCount();
      if (lastCount > 0) {
        _sessionExercises.add(ExerciseSet(
          exerciseName: _currentExerciseName!,
          reps: lastCount,
          sets: 1,
        ));
      }
    }

    _currentExerciseName = null;
    _activeCounter?.reset();

    setState(() {
      _exerciseCount = lastCount;
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

  // ==================== UI构建 ====================
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