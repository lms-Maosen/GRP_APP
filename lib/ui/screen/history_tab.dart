import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../i18n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../providers/history_provider.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  @override
  Widget build(BuildContext context) {
    // 获取多语言实例
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
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
                    loc.translate('record'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(loc.translate('viewYourWorkoutRecords')),
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
                    loc.translate('statistic'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(loc.translate('viewDetailedStatistics')),
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

// Record Page (修改为有状态)
class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final history = Provider.of<HistoryProvider>(context);
    final grouped = history.groupedByDate;

    // 按日期降序排序
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(loc.translate('record')),
        backgroundColor: const Color(0xFFC168EE),
        foregroundColor: Colors.white,
      ),
      body: sortedDates.isEmpty
          ? Center(
        child: Text(
          loc.translate('noRecords'), // 需添加翻译键
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final date = sortedDates[index];
          final exercises = grouped[date]!;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(
                _formatDate(date),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${exercises.length} ${loc.translate('exercises')}', // 需添加翻译键
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutDetailPage(
                      date: date,
                      exercises: exercises,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// 新增：详细页面显示该日所有运动组
class WorkoutDetailPage extends StatelessWidget {
  final DateTime date;
  final List<ExerciseSet> exercises;

  const WorkoutDetailPage({super.key, required this.date, required this.exercises});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    // 按运动名称分组（内部已合并相同次数的组）
    Map<String, List<ExerciseSet>> grouped = {};
    for (var set in exercises) {
      if (!grouped.containsKey(set.exerciseName)) {
        grouped[set.exerciseName] = [];
      }
      grouped[set.exerciseName]!.add(set);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_formatDate(date)),
        backgroundColor: const Color(0xFFC168EE),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: grouped.entries.map((entry) {
          final name = entry.key;
          final sets = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Image.asset(
                    _getExerciseImage(name),
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...sets.map((set) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${loc.translate('setsReps')}: ${set.sets}*${set.reps}', // 需添加翻译键
                            style: const TextStyle(fontSize: 16),
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getExerciseImage(String name) {
    switch (name.toLowerCase()) {
      case 'bicep curl':
        return 'assets/images/bicepcurl.png';
      case 'bench press':
        return 'assets/images/Bench press.png';
      case 'running':
        return 'assets/images/Running.png';
      case 'sit-up':
        return 'assets/images/Sit-up.png';
      case 'squat':
        return 'assets/images/Squat.png';
      case 'jump rope':
        return 'assets/images/Jump rope.png';
      default:
        return 'assets/images/Identify.png';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// Statistic Page with List Menu (保持不变)
class StatisticPage extends StatelessWidget {
  const StatisticPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(loc.translate('exerciseStatistics')),
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

// Exercise Detail Page with Slidable Bar Chart (保持不变)
class ExerciseDetailPage extends StatefulWidget {
  final String exerciseName;

  const ExerciseDetailPage({super.key, required this.exerciseName});

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<List<Map<String, dynamic>>> _weeklyData = [
    [
      {'date': '2025-11-01', 'reps': 25},
      {'date': '2025-11-02', 'reps': 30},
      {'date': '2025-11-03', 'reps': 28},
      {'date': '2025-11-04', 'reps': 35},
      {'date': '2025-11-05', 'reps': 32},
      {'date': '2025-11-06', 'reps': 40},
      {'date': '2025-11-07', 'reps': 38},
    ],
    [
      {'date': '2025-11-08', 'reps': 42},
      {'date': '2025-11-09', 'reps': 45},
      {'date': '2025-11-10', 'reps': 38},
      {'date': '2025-11-11', 'reps': 50},
      {'date': '2025-11-12', 'reps': 48},
      {'date': '2025-11-13', 'reps': 55},
      {'date': '2025-11-14', 'reps': 52},
    ],
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
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${widget.exerciseName} ${loc.translate('statistics')}'),
        backgroundColor: const Color(0xFFC168EE),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
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
                  '${loc.translate('week')} ${_currentPage + 1}',
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
                loc.translate('weeklyRepsProgress'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxReps(weekData) * 1.2,
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
                                text: '${rod.toY.toInt()} ${loc.translate('reps')}',
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
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${loc.translate('day')} ${index + 1}',
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
                            '${loc.translate('day')} ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            _formatDate(data['date']),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '${data['reps']} ${loc.translate('reps')}',
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