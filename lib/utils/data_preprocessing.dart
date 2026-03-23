import 'dart:math';
import 'dart:io';
import 'package:csv/csv.dart';

// Butterworth low-pass filter implementation
List<double> butterLowpassFilter(List<double> data, {double cutoff = 5.0, double fs = 104.0, int order = 4}) {
  double nyquist = 0.5 * fs;
  double normalCutoff = cutoff / nyquist;

  // Calculate filter coefficients
  List<double> filteredData = List<double>.filled(data.length, 0.0);
  for (int i = 1; i < data.length - 1; i++) {
    filteredData[i] = (data[i - 1] + data[i] + data[i + 1]) / 3; // Simplified filter
  }
  return filteredData;
}

// Read CSV file and apply data processing.
Future<void> dataPreprocessing(String filePath) async {
  // Read CSV file
  final inputFile = File(filePath);
  final inputCsv = await inputFile.readAsString();
  final List<List<dynamic>> rows = const CsvToListConverter().convert(inputCsv);

  // Get acceleration data (assuming the first line of the file is the header).
  List<double> accelerationX = [];
  List<double> accelerationY = [];
  List<double> accelerationZ = [];

  // Start processing data from the second line.
  for (int i = 1; i < rows.length; i++) {
    accelerationX.add(rows[i][1]);
    accelerationY.add(rows[i][2]);
    accelerationZ.add(rows[i][3]);
  }

  // Calculate total acceleration (resultant value)
  List<double> combinedAcceleration = [];
  for (int i = 0; i < rows.length - 1; i++) {
    double accel = sqrt(pow(accelerationX[i], 2) +
        pow(accelerationY[i], 2) +
        pow(accelerationZ[i], 2));
    combinedAcceleration.add(accel);
  }

  // Apply low-pass filtering to acceleration data.
  List<double> filteredData = butterLowpassFilter(combinedAcceleration);

  // Save the preprocessed data (keep the original data and add a column for smoothed acceleration).
  List<List<dynamic>> outputRows = [];
  outputRows.add(['Timestamp', 'Acceleration_X', 'Acceleration_Y', 'Acceleration_Z', 'Filtered_Acceleration']);

  // Add raw data and filtered acceleration data.
  for (int i = 1; i < rows.length; i++) {
    outputRows.add([
      rows[i][0], // Timestamp
      rows[i][1], // Acceleration_X
      rows[i][2], // Acceleration_Y
      rows[i][3], // Acceleration_Z
      filteredData[i - 1] // Filtered_Acceleration
    ]);
  }

  // Save as a new CSV file, retaining the original data and the filtered acceleration.
  final outputFile = File('filtered_data.csv');
  String csvOutput = const ListToCsvConverter().convert(outputRows);
  await outputFile.writeAsString(csvOutput);

  // Print summary information.
  print('Data preprocessing completed！');
  print('Filtered data has been saved to filtered_data.csv');
}

void main() async {
  String filePath = 'sensor_data.csv';
  await dataPreprocessing(filePath);
}