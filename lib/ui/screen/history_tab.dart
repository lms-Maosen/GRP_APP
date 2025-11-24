import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../i18n/app_localizations.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  @override
  Widget build(BuildContext context) {
    // 新增：获取多语言实例
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        // 新增：设置背景颜色
        color: const Color(0xFFC168EE),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Record Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                child: ListTile(
                  leading: const Icon(Icons.history, color: Colors.blue, size: 40),
                  title: Text(
                    loc.translate('record'), // 使用多语言翻译
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(loc.translate('viewYourWorkoutRecords')), // 使用多语言翻译
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RecordPage()),
                    );
                  },
                ),
              ),
            ),

            // Statistic Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                child: ListTile(
                  leading: const Icon(Icons.analytics, color: Colors.green, size: 40),
                  title: Text(
                    loc.translate('statistic'), // 使用多语言翻译
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(loc.translate('viewDetailedStatistics')), // 使用多语言翻译
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StatisticPage()),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Record Page
class RecordPage extends StatelessWidget {
  const RecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 新增：获取多语言实例
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(loc.translate('record')), // 使用多语言翻译
        backgroundColor: const Color(0xFFC168EE),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text(
          loc.translate('recordContentWillBeAddedLater'), // 使用多语言翻译
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}

// Statistic Page with List Menu
class StatisticPage extends StatelessWidget {
  const StatisticPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 新增：获取多语言实例
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(loc.translate('exerciseStatistics')), // 使用多语言翻译
        backgroundColor: const Color(0xFFC168EE),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          _buildExerciseListItem(loc.translate('chinUp'), 'assets/images/Chin-up.png', context),
          _buildExerciseListItem(loc.translate('benchPress'), 'assets/images/Bench press.png', context),
          _buildExerciseListItem(loc.translate('running'), 'assets/images/Running.png', context),
          _buildExerciseListItem(loc.translate('sitUp'), 'assets/images/Sit-up.png', context),
          _buildExerciseListItem(loc.translate('squat'), 'assets/images/Squat.png', context),
          _buildExerciseListItem(loc.translate('jumpRope'), 'assets/images/Jump rope.png', context),
        ],
      ),
    );
  }

  Widget _buildExerciseListItem(String exerciseName, String imagePath, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: Image.asset(
          imagePath,
          width: 50,
          height: 50,
          fit: BoxFit.contain,
        ),
        title: Text(
          exerciseName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExerciseDetailPage(exerciseName: exerciseName),
            ),
          );
        },
      ),
    );
  }
}

// Exercise Detail Page with Slidable Bar Chart
class ExerciseDetailPage extends StatefulWidget {
  final String exerciseName;

  const ExerciseDetailPage({super.key, required this.exerciseName});

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Sample data for demonstration - 3 weeks of data
  final List<List<Map<String, dynamic>>> _weeklyData = [
    // Week 1
    [
      {'date': '2025-11-01', 'reps': 25},
      {'date': '2025-11-02', 'reps': 30},
      {'date': '2025-11-03', 'reps': 28},
      {'date': '2025-11-04', 'reps': 35},
      {'date': '2025-11-05', 'reps': 32},
      {'date': '2025-11-06', 'reps': 40},
      {'date': '2025-11-07', 'reps': 38},
    ],
    // Week 2
    [
      {'date': '2025-11-08', 'reps': 42},
      {'date': '2025-11-09', 'reps': 45},
      {'date': '2025-11-10', 'reps': 38},
      {'date': '2025-11-11', 'reps': 50},
      {'date': '2025-11-12', 'reps': 48},
      {'date': '2025-11-13', 'reps': 55},
      {'date': '2025-11-14', 'reps': 52},
    ],
    // Week 3
    [
      {'date': '2025-11-15', 'reps': 58},
      {'date': '2025-11-16', 'reps': 60},
      {'date': '2025-11-17', 'reps': 55},
      {'date': '2025-11-18', 'reps': 65},
      {'date': '2025-11-19', 'reps': 62},
      {'date': '2025-11-20', 'reps': 70},
      {'date': '2025-11-21', 'reps': 68},
    ],
  ];

  @override
  Widget build(BuildContext context) {
    // 新增：获取多语言实例
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('${widget.exerciseName} ${loc.translate('statistics')}'), // 使用多语言翻译
        backgroundColor: const Color(0xFFC168EE),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Page indicator
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: _currentPage > 0
                      ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                      : null,
                ),
                Text(
                  '${loc.translate('week')} ${_currentPage + 1}', // 使用多语言翻译
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: _currentPage < _weeklyData.length - 1
                      ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                      : null,
                ),
              ],
            ),
          ),

          // PageView for slidable bar charts
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: _weeklyData.map((weekData) {
                return _buildBarChart(weekData, context);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> weekData, BuildContext context) {
    // 新增：获取多语言实例
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                loc.translate('weeklyRepsProgress'), // 使用多语言翻译
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxReps(weekData) * 1.2, // Add some padding at the top
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: Colors.grey[800],
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${weekData[groupIndex]['date']}\n',
                            const TextStyle(color: Colors.white),
                            children: [
                              TextSpan(
                                text: '${rod.toY.toInt()} ${loc.translate('reps')}', // 使用多语言翻译
                                style: const TextStyle(
                                  color: Colors.yellow,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < weekData.length) {
                              // Show only day number (e.g., 1, 2, 3...)
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${loc.translate('day')} ${index + 1}', // 使用多语言翻译
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }
                            return const Text('');
                          },
                          reservedSize: 40,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 12),
                            );
                          },
                          reservedSize: 40,
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: const Color(0xff37434d), width: 1),
                    ),
                    barGroups: weekData.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: data['reps'].toDouble(),
                            gradient: _getBarGradient(data['reps']),
                            width: 20,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                        showingTooltipIndicators: [0],
                      );
                    }).toList(),
                    gridData: const FlGridData(show: true),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Date labels below the chart
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: weekData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Text(
                            '${loc.translate('day')} ${index + 1}', // 使用多语言翻译
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            _formatDate(data['date']),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '${data['reps']} ${loc.translate('reps')}', // 使用多语言翻译
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getMaxReps(List<Map<String, dynamic>> data) {
    return data.map((item) => item['reps'].toDouble()).reduce((a, b) => a > b ? a : b);
  }

  LinearGradient _getBarGradient(int reps) {
    if (reps >= 60) {
      return LinearGradient(
        colors: [Colors.green[300]!, Colors.green[700]!],
      );
    } else if (reps >= 40) {
      return LinearGradient(
        colors: [Colors.blue[300]!, Colors.blue[700]!],
      );
    } else {
      return LinearGradient(
        colors: [Colors.orange[300]!, Colors.orange[700]!],
      );
    }
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.month}/${date.day}';
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}