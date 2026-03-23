import 'dart:io';
import 'dart:async';
import 'package:csv/csv.dart';

// 1. 工具函数：安全转换数字（容错）
double safeParseDouble(dynamic value) {
  try {
    return double.parse(value.toString());
  } catch (e) {
    print("数据转换错误: $value");
    return 0.0;
  }
}

// 2. 工具函数：读取已滤波数据（Windows适配）
Future<List<List<dynamic>>> readFilteredCsv(String filePath) async {
  final inputFile = File(filePath);
  if (!await inputFile.exists()) {
    throw FileSystemException("已滤波数据文件不存在，请检查路径: $filePath");
  }
  final inputCsv = await inputFile.readAsString();
  return const CsvToListConverter().convert(inputCsv);
}

// 3. 核心类：手环跑步距离计数器（调整阈值+平滑参数，解决漏计）
class WristRunningCounter {
  int _swingCycle = 0;        // 摆臂周期数
  bool _isPeakDetected = false; // 标记向前摆峰值
  
  // 🔥 调整后更宽松的阈值（适配实际摆臂，减少漏计）
  double swingPeakThreshold;   // 向前摆峰值：1.0（原1.3，更宽松）
  double swingValleyThreshold; // 向后摆谷值：-0.8（原-1.1，更宽松）
  
  // 调整后更灵敏的平滑参数
  final List<double> _dataBuffer = [];
  final int _bufferSize = 3;    // 窗口从5→3，更快响应
  final int _minInterval = 3;   // 间隔从6→3，适配高频摆臂
  int _sampleCounter = 0;

  // 构造函数：初始化调整后的阈值
  WristRunningCounter({
    double swingPeakThreshold = 0.8,
    double swingValleyThreshold = -0.5,
  })  : swingPeakThreshold = swingPeakThreshold,
        swingValleyThreshold = swingValleyThreshold;

  // 获取总距离（1周期=1.6米，逻辑不变）
  double get totalDistance => _swingCycle * 1.6;

  // 核心：X轴摆臂周期识别（逻辑不变，仅参数调整）
  void countSwingCycleByXAxis(double xValue) {
    _dataBuffer.add(xValue);
    if (_dataBuffer.length > _bufferSize) _dataBuffer.removeAt(0);
    if (_dataBuffer.length < _bufferSize) return;

    double avgX = _dataBuffer.reduce((a, b) => a + b) / _bufferSize;
    _sampleCounter++;

    // 摆臂周期判定（更宽松的阈值，减少漏计）
    if (avgX > swingPeakThreshold && !_isPeakDetected && _sampleCounter >= _minInterval) {
      _isPeakDetected = true;
      _sampleCounter = 0;
    } else if (avgX < swingValleyThreshold && _isPeakDetected && _sampleCounter >= _minInterval) {
      _swingCycle++;
      _isPeakDetected = false;
      _sampleCounter = 0;
    }
  }

  // 重置计数
  void resetCount() {
    _swingCycle = 0;
    _isPeakDetected = false;
    _dataBuffer.clear();
    _sampleCounter = 0;
  }

  // 微调阈值方法（后续可手动调整）
  void adjustThreshold({double? newPeak, double? newValley}) {
    if (newPeak != null) swingPeakThreshold = newPeak;
    if (newValley != null) swingValleyThreshold = newValley;
    resetCount();
  }
}

// 4. 执行方法：计算最终距离
Future<void> calculateRunningDistance(String filePath) async {
  final runningCounter = WristRunningCounter();

  print("正在读取已滤波的 filtered_data.csv 数据...");
  final rows = await readFilteredCsv(filePath);
  if (rows.length <= 1) {
    print("数据为空或仅有表头，无法计算距离");
    return;
  }

  // 打印X轴特征，验证阈值
  double xMin = double.infinity;
  double xMax = -double.infinity;
  for (int i = 1; i < rows.length; i++) {
    double x = safeParseDouble(rows[i][1]);
    if (x < xMin) xMin = x;
    if (x > xMax) xMax = x;
  }
  print("\n=== 已滤波数据X轴特征 ===");
  print("X轴范围：min=$xMin, max=$xMax");
  print("当前阈值：swingPeak=${runningCounter.swingPeakThreshold}, swingValley=${runningCounter.swingValleyThreshold}\n");

  print("正在计算跑步距离...");
  for (int i = 1; i < rows.length; i++) {
    final xValue = safeParseDouble(rows[i][1]);
    runningCounter.countSwingCycleByXAxis(xValue);
  }

  print("\n=====================");
  print("跑步距离计算完成！");
  print("总摆臂周期数：${runningCounter._swingCycle}");
  print("最终跑步距离：${runningCounter.totalDistance.toStringAsFixed(1)} 米");
  print("=====================");
}

// 5. 入口函数
void main() async {
  const csvPath = 'filtered_data.csv';
  try {
    await calculateRunningDistance(csvPath);
  } catch (e) {
    print("距离计算失败：$e");
  }
}