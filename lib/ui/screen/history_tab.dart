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
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        color: const Color(0xFFC168EE),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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

// ==================== Record Page ====================
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
          loc.translate('noRecords'),
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
                '${exercises.length} ${loc.translate('exercises')}',
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

class WorkoutDetailPage extends StatelessWidget {
  final DateTime date;
  final List<ExerciseSet> exercises;

  const WorkoutDetailPage({super.key, required this.date, required this.exercises});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

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
                            '${loc.translate('setsReps')}: ${set.sets}*${set.reps}',
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
      case 'squat':
        return 'assets/images/Squat.png';
      default:
        return 'assets/images/Identify.png';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// ==================== Statistic Page ====================
class StatisticPage extends StatelessWidget {
  const StatisticPage({super.key});

  final List<Map<String, String>> _exercises = const [
    {'key': 'squat', 'image': 'assets/images/Squat.png', 'nameKey': 'squat'},
    {'key': 'bench press', 'image': 'assets/images/Bench press.png', 'nameKey': 'benchPress'},
    {'key': 'running', 'image': 'assets/images/Running.png', 'nameKey': 'running'},
    {'key': 'bicep', 'image': 'assets/images/bicepcurl.png', 'nameKey': 'bicepCurl'},
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
        title: Text(loc.translate('exerciseStatistics')),
        backgroundColor: const Color(0xFFC168EE),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: _exercises.map((item) {
          return _buildExerciseListItem(
            context: context,
            exerciseKey: item['key']!,
            nameKey: item['nameKey']!,
            imagePath: item['image']!,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExerciseListItem({
    required BuildContext context,
    required String exerciseKey,
    required String nameKey,
    required String imagePath,
  }) {
    final loc = AppLocalizations.of(context);
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
          loc.translate(nameKey),
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
              builder: (context) => ExerciseDetailPage(exerciseKey: exerciseKey),
            ),
          );
        },
      ),
    );
  }
}

// ==================== Exercise Detail Page ====================
class ExerciseDetailPage extends StatefulWidget {
  final String exerciseKey;

  const ExerciseDetailPage({super.key, required this.exerciseKey});

  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  Map<DateTime, int> _getAggregatedData(HistoryProvider history) {
    final Map<DateTime, int> data = {};
    for (var session in history.sessions) {
      for (var set in session.exercises) {
        if (set.exerciseName.toLowerCase() == widget.exerciseKey.toLowerCase()) {
          final date = DateTime(session.date.year, session.date.month, session.date.day);
          data[date] = (data[date] ?? 0) + (set.reps * set.sets);
        }
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final history = Provider.of<HistoryProvider>(context);
    final aggregated = _getAggregatedData(history);
    final sortedEntries = aggregated.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${loc.translate(widget.exerciseKey)} ${loc.translate('statistics')}'),
        backgroundColor: const Color(0xFFC168EE),
        foregroundColor: Colors.white,
      ),
      body: sortedEntries.isEmpty
          ? Center(
        child: Text(
          loc.translate('noData'),
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  loc.translate('exerciseHistory'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: (sortedEntries.length * 60.0).clamp(200.0, double.infinity),
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _getMaxY(sortedEntries) * 1.2,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.grey[800],
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final entry = sortedEntries[group.x];
                                return BarTooltipItem(
                                  '${_formatDate(entry.key)}\n',
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
                                  if (index >= 0 && index < sortedEntries.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        _formatDateShort(sortedEntries[index].key),
                                        style: const TextStyle(fontSize: 10),
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
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                                reservedSize: 30,
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(color: const Color(0xff37434d), width: 1),
                          ),
                          barGroups: List.generate(sortedEntries.length, (index) {
                            final entry = sortedEntries[index];
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.toDouble(),
                                  gradient: _getBarGradient(entry.value),
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                              showingTooltipIndicators: [0],
                            );
                          }),
                          gridData: const FlGridData(show: true),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _getMaxY(List<MapEntry<DateTime, int>> entries) {
    return entries.map((e) => e.value.toDouble()).fold(0, (a, b) => a > b ? a : b);
  }

  LinearGradient _getBarGradient(int reps) {
    if (reps >= 60) {
      return LinearGradient(colors: [Colors.green[300]!, Colors.green[700]!]);
    } else if (reps >= 40) {
      return LinearGradient(colors: [Colors.blue[300]!, Colors.blue[700]!]);
    } else {
      return LinearGradient(colors: [Colors.orange[300]!, Colors.orange[700]!]);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateShort(DateTime date) {
    return '${date.month}/${date.day}';
  }
}