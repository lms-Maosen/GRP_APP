import 'dart:math';
import 'dart:io';
import 'package:csv/csv.dart';

// 巴特沃斯低通滤波器实现
List<double> butterLowpassFilter(List<double> data, {double cutoff = 5.0, double fs = 104.0, int order = 4}) {
  double nyquist = 0.5 * fs;
  double normalCutoff = cutoff / nyquist;

  // 计算滤波器系数
  List<double> filteredData = List<double>.filled(data.length, 0.0);
  for (int i = 1; i < data.length - 1; i++) {
    filteredData[i] = (data[i - 1] + data[i] + data[i + 1]) / 3; // 简化滤波器
  }
  return filteredData;
}

// 读取CSV文件并应用数据处理
Future<void> dataPreprocessing(String filePath) async {
  // 读取CSV文件
  final inputFile = File(filePath);
  final inputCsv = await inputFile.readAsString();
  final List<List<dynamic>> rows = const CsvToListConverter().convert(inputCsv);

  // 获取加速度数据（假设文件第一行是标题）
  List<double> accelerationX = [];
  List<double> accelerationY = [];
  List<double> accelerationZ = [];

  // 从第二行开始处理数据
  for (int i = 1; i < rows.length; i++) {
    accelerationX.add(rows[i][1]);
    accelerationY.add(rows[i][2]);
    accelerationZ.add(rows[i][3]);
  }

  // 计算总加速度（合成值）
  List<double> combinedAcceleration = [];
  for (int i = 0; i < rows.length - 1; i++) {
    double accel = sqrt(pow(accelerationX[i], 2) +
        pow(accelerationY[i], 2) +
        pow(accelerationZ[i], 2));
    combinedAcceleration.add(accel);
  }

  // 对加速度数据应用低通滤波
  List<double> filteredData = butterLowpassFilter(combinedAcceleration);

  // 保存预处理后的数据（保留原始数据，并加一列平滑加速度）
  List<List<dynamic>> outputRows = [];
  outputRows.add(['Timestamp', 'Acceleration_X', 'Acceleration_Y', 'Acceleration_Z', 'Filtered_Acceleration']); // 添加标题行

  // 添加原始数据以及滤波后的加速度数据
  for (int i = 1; i < rows.length; i++) {
    outputRows.add([
      rows[i][0], // Timestamp
      rows[i][1], // Acceleration_X
      rows[i][2], // Acceleration_Y
      rows[i][3], // Acceleration_Z
      filteredData[i - 1] // Filtered_Acceleration
    ]);
  }

  // 保存为新的CSV文件，保留原始数据及滤波后的加速度
  final outputFile = File('filtered_data.csv');
  String csvOutput = const ListToCsvConverter().convert(outputRows);
  await outputFile.writeAsString(csvOutput);

  // 打印总结性信息
  print('数据预处理完成！');
  print('滤波后的数据已保存到 filtered_data.csv');
}

void main() async {
  String filePath = 'sensor_data.csv'; // 替换为实际的文件路径
  await dataPreprocessing(filePath);
}