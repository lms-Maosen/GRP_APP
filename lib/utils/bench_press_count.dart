import 'dart:io';
import 'dart:async';
import 'package:csv/csv.dart';

// 1. 工具函数：安全转换数字（容错处理，避免脏数据崩溃）
double safeParseDouble(dynamic value) {
  try {
    return double.parse(value.toString());
  } catch (e) {
    print("数据转换错误: $value");
    return 0.0;
  }
}

// 2. 工具函数：读取卧推CSV数据（Windows适配，相对路径）
Future<List<List<dynamic>>> readBenchPressCsv(String filePath) async {
  final inputFile = File(filePath);
  if (!await inputFile.exists()) {
    throw FileSystemException("卧推数据文件不存在，请检查路径: $filePath");
  }
  final inputCsv = await inputFile.readAsString();
  return const CsvToListConverter().convert(inputCsv);
}

// 3. 核心类：卧推计数器（适配卧推动作特征，防抖+平滑）
class BenchPressCounter {
  int _count = 0;          // 卧推总次数
  bool _isLowered = false; // 标记是否处于「杠铃已下降」状态（区分动作阶段）
  
  // 🔥 卧推专属阈值（基于数据校准，变量名替换：valley=谷值/下降，peak=峰值/上升）
  double valleyThreshold;  // 谷值阈值（杠铃下降：低于此值=杠铃开始下降）
  double peakThreshold;    // 峰值阈值（杠铃上升：高于此值=杠铃上升，完成一次卧推）

  // 数据缓存：平滑传感器波动（10个样本窗口，避免单次抖动误判）
  final List<double> _dataBuffer = [];
  final int _bufferSize = 10;
  int _sampleCounter = 0; // 样本间隔计数器
  final int _minInterval = 12; // 卧推动作最小间隔（避免快速波动误判）

  // 构造函数：初始化卧推阈值（变量名替换，默认值保持不变）
  BenchPressCounter({
    double valleyThreshold = -1.5,  // 原lowerThreshold，谷值阈值（下降判定）
    double peakThreshold = 0.3,   // 原liftThreshold，峰值阈值（上升判定）
  })  : valleyThreshold = valleyThreshold,
        peakThreshold = peakThreshold;

  // 获取当前计数
  int get count => _count;

  // 4. 核心方法：单轴（Z轴）卧推计数逻辑（变量名同步替换）
  void countByZAxis(double filteredZValue) {
    // 步骤1：缓存数据，保持窗口大小（平滑处理）
    _dataBuffer.add(filteredZValue);
    if (_dataBuffer.length > _bufferSize) _dataBuffer.removeAt(0);
    if (_dataBuffer.length < _bufferSize) return; // 缓存未满不判断，避免误判

    // 步骤2：计算缓存平均值（过滤传感器抖动）
    double avgZValue = _dataBuffer.reduce((a, b) => a + b) / _bufferSize;
    _sampleCounter++;

    // 步骤3：卧推动作完整循环判断（下降→上升，变量名同步替换）
    // 情况1：杠铃下降（平均值低于谷值阈值，且未标记下降状态）
    if (avgZValue < valleyThreshold && !_isLowered && _sampleCounter >= _minInterval) {
      _isLowered = true;       // 标记为「已下降」
      _sampleCounter = 0;      // 重置间隔计数器
    }
    // 情况2：杠铃上升（平均值高于峰值阈值，且已标记下降→完成一次卧推）
    else if (avgZValue > peakThreshold && _isLowered && _sampleCounter >= _minInterval) {
      _count++;                // 卧推次数+1
      _isLowered = false;      // 重置下降标记
      _sampleCounter = 0;      // 重置间隔计数器
    }
  }

  // 5. 辅助方法：重置计数（重新计数时使用）
  void resetCount() {
    _count = 0;
    _isLowered = false;
    _dataBuffer.clear();
    _sampleCounter = 0;
  }

  // 6. 辅助方法：调整阈值（变量名替换，适配不同人/设备的数据）
  void adjustThreshold({double? newValley, double? newPeak}) {
    if (newValley != null) valleyThreshold = newValley; // 原newLower→newValley
    if (newPeak != null) peakThreshold = newPeak;       // 原newLift→newPeak
    resetCount(); // 调整阈值后重置计数
  }
}

// 7. 执行方法：读取卧推数据并实时计数（完成一次打印一次，无刷屏）
Future<void> startBenchPressCounting(String filePath) async {
  // 初始化卧推计数器（变量名替换：valleyThreshold/peakThreshold）
  final benchCounter = BenchPressCounter(
    valleyThreshold: -1.5,  // 原lowerThreshold
    peakThreshold: 0.3     // 原liftThreshold
  );
  int lastCount = 0; // 记录上一次计数，避免重复打印（核心：只在计数+1时打印）

  // 读取卧推CSV数据
  print("正在读取卧推数据...");
  final rows = await readBenchPressCsv(filePath);
  if (rows.length <= 1) {
    print("数据为空或仅有表头，无法计数");
    return;
  }

  // 遍历数据并实时计数（跳过表头，从第2行开始）
  print("开始卧推计数（完成一次打印一次）...\n");
  for (int i = 1; i < rows.length; i++) {
    // 读取Z轴加速度数据（第4列，索引3，和深蹲代码一致）
    final zValue = safeParseDouble(rows[i][3]);
    // 实时更新计数
    benchCounter.countByZAxis(zValue);

    // 仅当完成新一次卧推时打印（避免刷屏，和深蹲代码逻辑一致）
    final currentCount = benchCounter.count;
    if (currentCount > lastCount) {
      print("实时卧推次数为：$currentCount");
      lastCount = currentCount;
      // 可选：模拟真实运动间隔（卧推单次约1秒，可保留延迟，也可删除）
      // await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  // 输出最终结果
  print("\n=====================");
  print("卧推计数结束，最终次数：${benchCounter.count}");
  print("=====================");
}

// 8. 入口函数：执行卧推计数（Windows适配，相对路径）
void main() async {
  // 修正：使用相对路径，直接读取当前目录的filtered_data.csv（和深蹲代码一致）
  const csvPath = 'filtered_data.csv';
  try {
    await startBenchPressCounting(csvPath);
  } catch (e) {
    print("计数失败：$e");
  }
}