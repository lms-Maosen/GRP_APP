import 'dart:io';
import 'package:csv/csv.dart';
import 'dart:math';

// 读取CSV文件并应用数据处理
Future<List<List<dynamic>>> readCsv(String filePath) async {
  final inputFile = File(filePath);
  final inputCsv = await inputFile.readAsString();
  return const CsvToListConverter().convert(inputCsv);
}

// 检测深蹲计数（只考虑Z轴加速度变化）
int countSquats(List<double> filteredZAcceleration) {
  int count = 0;
  bool isInSquat = false; // 标记当前是否处于深蹲动作中

  // 设置阈值，避免过小波动
  double threshold = 6.3; // 调整阈值，确保能检测到更多的波动

  // 可以增加对连续两次波动的判断，防止误判
  for (int i = 1; i < filteredZAcceleration.length; i++) {
    if (filteredZAcceleration[i] < threshold && !isInSquat) {
      // 进入深蹲下蹲阶段
      isInSquat = true;
    } else if (filteredZAcceleration[i] > threshold && isInSquat) {
      // 完成一次深蹲起身阶段
      count++;
      isInSquat = false;
    }
  }

  return count;
}

// 读取数据并计算深蹲次数
Future<void> processAndCountSquats(String filePath) async {
  List<List<dynamic>> rows = await readCsv(filePath);

  // 获取 Z 轴的加速度数据
  List<double> filteredZAcceleration = [];
  for (int i = 1; i < rows.length; i++) {
    filteredZAcceleration.add(rows[i][3]); // 获取 Z 轴加速度数据（假设在第 4 列）
  }

  // 进行深蹲计数
  int squatCount = countSquats(filteredZAcceleration);

  // 打印结果到命令窗口
  print("蹲起的次数为：$squatCount");
}

void main() async {
  String filePath = 'filtered_data.csv'; // 替换为实际的文件路径
  await processAndCountSquats(filePath);
}