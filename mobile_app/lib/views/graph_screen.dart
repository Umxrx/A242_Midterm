import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:my_project/models/reading.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  List<Reading> readings = [];
  List<Reading> lastValidReadings = [];
  Timer? refreshTimer;
  bool showAlert = false;

  @override
  void initState() {
    super.initState();
    fetchReadings();
    scheduleRefresh();
  }

  void scheduleRefresh() {
    final now = DateTime.now();
    final secondsToNextTick = 10 - now.second % 10;
    Future.delayed(Duration(seconds: secondsToNextTick), () {
      fetchReadings();
      refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => fetchReadings());
    });
  }

  Future<void> fetchReadings() async {
    final uri = Uri.parse('https://umairsuhaimee.com/sensor_data/get_readings.php');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final List<dynamic> rawList = body['data'];
      final List<Map<String, dynamic>> parsedData = rawList.map((e) => Map<String, dynamic>.from(e)).toList();

      final now = DateTime.now();
      final lastHour = now.subtract(const Duration(hours: 1));
      List<Reading> tempReadings = [];

      double lastTemp = 0;
      double lastHum = 0;

      for (int i = 0; i < 360; i++) {
        final pointTime = lastHour.add(Duration(seconds: i * 10));
        final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(pointTime);

        final match = parsedData.firstWhere(
          (e) => e['timestamp'] == timeStr,
          orElse: () => {},
        );

        double temp = match.containsKey('temperature') ? double.tryParse(match['temperature'].toString()) ?? 0 : 0;
        double hum = match.containsKey('humidity') ? double.tryParse(match['humidity'].toString()) ?? 0 : 0;

        if (temp == 0 && lastTemp != 0) temp = lastTemp;
        if (hum == 0 && lastHum != 0) hum = lastHum;
        if (temp != 0) lastTemp = temp;
        if (hum != 0) lastHum = hum;

        tempReadings.add(
          Reading(
            id: match.containsKey('id') ? int.tryParse(match['id'].toString()) ?? 0 : 0,
            deviceId: match.containsKey('device_id') ? match['device_id'].toString() : '',
            alert: match.containsKey('alert') ? int.tryParse(match['alert'].toString()) ?? 0 : 0,
            timestamp: pointTime,
            temperature: temp,
            humidity: hum,
          ),
        );
      }

      final allZero = tempReadings.every((r) => r.temperature == 0 && r.humidity == 0);

      if (!allZero) {
        setState(() {
          readings = tempReadings;
          lastValidReadings = tempReadings;
          showAlert = readings.last.alert == 1;
        });
      } else {
        log('All-zero data received — fallback to last graph.');
        setState(() {
          readings = lastValidReadings;
        });
      }
    } else {
      log('Fetch failed — fallback to last graph.');
      setState(() {
        readings = lastValidReadings;
      });
    }
  }

  List<FlSpot> tempSpots() => List.generate(
        readings.length,
        (i) => FlSpot(i.toDouble(), readings[i].temperature),
      );

  List<FlSpot> humSpots() => List.generate(
        readings.length,
        (i) => FlSpot(i.toDouble(), readings[i].humidity),
      );

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Real-time Sensor Graph")),
      body: Column(
        children: [
          if (showAlert)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.redAccent,
              child: const Text(
                "Alert: High Temperature!",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              minScale: 1,
              maxScale: 5,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 100,
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 60,
                          getTitlesWidget: (value, meta) {
                            if (value % 60 == 0 && value >= 0 && value < readings.length) {
                              final time = readings[value.toInt()].timestamp;
                              return Text(DateFormat.Hm().format(time),
                                  style: const TextStyle(fontSize: 10));
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 10,
                          getTitlesWidget: (value, _) {
                            return Text(
                              '${value.toInt()}(°/%)',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: showAlert
                          ? [
                              HorizontalLine(
                                y: 35,
                                color: Colors.red,
                                strokeWidth: 1,
                                dashArray: [6, 3],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.centerLeft,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  labelResolver: (_) => '35°',
                                ),
                              ),
                            ]
                          : [],
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: tempSpots(),
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.withAlpha(153),
                              Colors.orange.withAlpha(0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      LineChartBarData(
                        spots: humSpots(),
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withAlpha(153),
                              Colors.blue.withAlpha(0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        tooltipPadding: const EdgeInsets.all(8),
                        tooltipBorderRadius: BorderRadius.circular(8),
                        tooltipMargin: 8,
                        fitInsideVertically: true,
                        tooltipBorder: BorderSide(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final reading = readings[spot.x.toInt()];
                            final timeStr = DateFormat.Hms().format(reading.timestamp);

                            final isTemp = spot.bar.color == Colors.orange;
                            final label = isTemp ? 'Temp' : 'Hum';
                            final value = '${spot.y.toStringAsFixed(1)}°';

                            final tooltipText = '$timeStr\n$label: $value';

                            return LineTooltipItem(
                              tooltipText,
                              TextStyle(
                                color: spot.bar.color,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                height: 1.3,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: const Border(
                        left: BorderSide(color: Colors.black, width: 1),
                        bottom: BorderSide(color: Colors.black, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
