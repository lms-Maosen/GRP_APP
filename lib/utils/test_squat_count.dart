import 'dart:io';
import 'dart:async';
import 'package:csv/csv.dart';
import 'dart:math';

// 安全地将字符串转换为 double，若失败则返回 0.0
double safeParseDouble(dynamic value) {
  try {
    return double.parse(value.toString());
  } catch (e) {
    print("无法转换为数字: $value");
    return 0.0; // 如果无法转换为 double，则返回 0.0
  }
}

// 读取CSV文件并应用数据处理
Future<List<List<dynamic>>> readCsv(String filePath) async {
  final inputFile = File(filePath);
  final inputCsv = await inputFile.readAsString();
  return const CsvToListConverter().convert(inputCsv);
}

class SquatCounter {
  int _count = 0;
  bool _isPeakDetected = false;

  // 设定阈值
  double peakThreshold;   // 设置峰值阈值（起身时）
  double valleyThreshold; // 设置谷值阈值（下蹲时）

  // 缓存数据和最小间隔
  final List<double> _dataBuffer = [];
  final int _bufferSize = 10;  // 缓存窗口
  int _sampleCounter = 0;
  final int _minInterval = 15; // 最小间隔

  SquatCounter({
    double peakThreshold = 7.5,
    double valleyThreshold = 6.0,
  })  : peakThreshold = peakThreshold,
        valleyThreshold = valleyThreshold;

  int get count => _count;

  // 实时更新计数
  void countBySingleAxis(double filteredValue) {
    _dataBuffer.add(filteredValue);
    if (_dataBuffer.length > _bufferSize) _dataBuffer.removeAt(0);
    if (_dataBuffer.length < _bufferSize) return;

    double avgValue = _dataBuffer.reduce((a, b) => a + b) / _bufferSize;
    _sampleCounter++;

    // 判断下蹲阶段
    if (avgValue < peakThreshold && !_isPeakDetected && _sampleCounter >= _minInterval) {
      _isPeakDetected = true;  // 进入下蹲阶段
      _sampleCounter = 0;      // 重置计数
    } else if (avgValue > valleyThreshold && _isPeakDetected && _sampleCounter >= _minInterval) {
      _count++;  // 完成一次深蹲
      _isPeakDetected = false;  // 退出深蹲状态
      _sampleCounter = 0;       // 重置计数
    }
  }

  // 处理三轴加速度数据
  void countBy3Axis(Map<String, double> filtered3Axis) {
    double zValue = filtered3Axis['z'] ?? 0.0;
    countBySingleAxis(zValue);
  }

  void resetCount() {
    _count = 0;
    _isPeakDetected = false;
    _dataBuffer.clear();
    _sampleCounter = 0;
  }

  // 调整阈值
  void adjustThreshold({double? newPeak, double? newValley}) {
    if (newPeak != null) peakThreshold = newPeak;
    if (newValley != null) valleyThreshold = newValley;
    resetCount();
  }
}

// 实时深蹲计数器（修改后的打印逻辑）
Future<void> startRealTimeSquatCounting(String filePath) async {
  SquatCounter squatCounter = SquatCounter(peakThreshold: 7.5, valleyThreshold: 6.0);
  // 🔴 核心修改1：新增变量记录上一次的计数，初始为0
  int lastCount = 0;

  // 读取CSV数据（模拟实时数据流）
  List<List<dynamic>> rows = await readCsv(filePath);

  // 遍历每行数据并更新计数
  for (int i = 1; i < rows.length; i++) {
    double filteredZAcceleration = safeParseDouble(rows[i][3]);
    squatCounter.countBySingleAxis(filteredZAcceleration);

    // 🔴 核心修改2：仅当计数增加（完成新深蹲）时打印
    int currentCount = squatCounter.count;
    if (currentCount > lastCount) {
      print("实时深蹲次数为：$currentCount");
      // 如需模拟真实运动间隔，可保留延迟（建议毫秒级，避免卡顿）
      // await Future.delayed(Duration(milliseconds: 100));
      // 更新上一次计数，避免重复打印
      lastCount = currentCount;
    }
  }

  // 输出最终总次数
  print("\n最终深蹲次数为：${squatCounter.count}");
}

void main() async {
  String filePath = 'filtered_data.csv'; // 替换为实际的文件路径
  await startRealTimeSquatCounting(filePath);  // 实时计数
}