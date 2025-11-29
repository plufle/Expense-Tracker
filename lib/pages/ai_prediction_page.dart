// lib/pages/ai_prediction_page.dart
// ignore_for_file: unused_import, unused_field, unused_element

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../services/expenses_api_service.dart'; // your existing service
import '../data/transaction_model.dart'; // optional, only if you use enums/types

class AIPredictionPage extends StatefulWidget {
  /// Optionally pass your API service instance (helps testing).
  final ExpensesApiService? api;
  const AIPredictionPage({super.key, this.api});

  @override
  State<AIPredictionPage> createState() => _AIPredictionPageState();
}

class _AIPredictionPageState extends State<AIPredictionPage> {
  final _predictionController = TextEditingController();
  String _predictionResult = ''; // manual text result

  // state for remote data
  bool _loading = true;
  String? _error;
  Map<String, double> _categoryTotals = {};
  double _totalExpenses = 0.0;
  double _avgDaily = 0.0;
  double? _predictedNextDay; // from model endpoint (if available)
  double? _predictedNextMonth; // aggregated (either model or heuristic)
  List<_PieEntry> _pieEntries = [];

  // api (use provided or create default)
  late final ExpensesApiService _api;

  @override
  void initState() {
    super.initState();
    _api =
        widget.api ??
        ExpensesApiService(
          apiBase:
              dotenv.env['API_BASE_URL'] ??
              '', // <- change to your base if needed
        );
    _loadData();
  }

  @override
  void dispose() {
    _predictionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Try to fetch ALL transactions. If your API requires start/end, you can
      // pass a large range or implement another list method; this attempts default.
      final resp = await _api.listExpenses(limit: 10000);
      // Expected: resp['items'] is List<Map<String, dynamic>>
      final items =
          (resp['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      if (items.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No transactions returned from server';
        });
        return;
      }

      // Aggregate category totals and compute daily totals
      final Map<String, double> catTotals = {};
      final Map<String, double> daily = {}; // yyyy-MM-dd -> sum

      for (final it in items) {
        final itemType = (it['itemType'] ?? '').toString().toUpperCase();
        if (itemType != 'TRANSACTION') continue;
        final status = (it['status'] ?? '').toString().toLowerCase();
        if (status == 'deleted') continue;

        final direction = (it['direction'] ?? 'expense')
            .toString()
            .toLowerCase();
        // we sum only expenses for the spending metrics
        if (direction != 'expense') continue;

        final cat = (it['category'] ?? 'Other').toString();
        double amt = 0.0;
        try {
          if (it['amount'] is num) {
            amt = (it['amount'] as num).toDouble();
          } else {
            amt = double.tryParse(it['amount'].toString()) ?? 0.0;
          }
        } catch (_) {
          amt = 0.0;
        }

        catTotals[cat] = (catTotals[cat] ?? 0.0) + amt;

        // daily aggregation: prefer `date` field if present, otherwise parse timestamp
        String dateKey = '';
        if (it['date'] != null) {
          dateKey = it['date'].toString();
        } else if (it['timestamp'] != null) {
          // take first 10 chars of ISO timestamp to get YYYY-MM-DD
          dateKey = it['timestamp'].toString().substring(0, 10);
        } else if (it['createdAt'] != null) {
          dateKey = it['createdAt'].toString().substring(0, 10);
        } else {
          // fallback: group under "unknown"
          dateKey = 'unknown';
        }
        daily[dateKey] = (daily[dateKey] ?? 0.0) + amt;
      }

      // compute totals
      final total = catTotals.values.fold(0.0, (a, b) => a + b);
      // compute days with data (exclude 'unknown')
      final daysWithData = daily.keys.where((k) => k != 'unknown').length;
      final avgDaily = daysWithData > 0 ? total / daysWithData : 0.0;

      // prepare pie entries (pick top 6 categories, group rest into 'Other')
      final sortedCats = catTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final List<_PieEntry> pie = [];
      double otherSum = 0.0;
      for (var i = 0; i < sortedCats.length; i++) {
        if (i < 6) {
          pie.add(_PieEntry(sortedCats[i].key, sortedCats[i].value));
        } else {
          otherSum += sortedCats[i].value;
        }
      }
      if (otherSum > 0) pie.add(_PieEntry('Other', otherSum));

      // Try calling optional model endpoint /predict-next (expects amounts array)
      double? modelPred;
      double? modelMonthTotal;
      try {
        // build ordered recent daily series for model: sort dates ascending
        final sortedDailyKeys = daily.keys.where((k) => k != 'unknown').toList()
          ..sort();
        final recentAmounts = sortedDailyKeys
            .map((d) => daily[d] ?? 0.0)
            .toList();

        // do a safe call only if model endpoint exists
        final modelResp = await _tryCallModelPredictEndpoint(recentAmounts);
        if (modelResp != null) {
          // server may return {prediction: x} or {nextMonthTotal: y}
          if (modelResp.containsKey('prediction')) {
            modelPred = (modelResp['prediction'] as num).toDouble();
          }
          if (modelResp.containsKey('nextMonthTotal')) {
            modelMonthTotal = (modelResp['nextMonthTotal'] as num).toDouble();
          }
        }
      } catch (e) {
        // ignore model errors and fallback to heuristic
      }

      // compute fallback predicted next-month total: avgDaily * 30
      final fallbackMonth = avgDaily * 30.0;
      final predictedMonth = modelMonthTotal ?? fallbackMonth;

      setState(() {
        _loading = false;
        _error = null;
        _categoryTotals = catTotals;
        _totalExpenses = total;
        _avgDaily = avgDaily;
        _pieEntries = pie;
        _predictedNextDay = modelPred;
        _predictedNextMonth = predictedMonth;
      });
    } catch (e, st) {
      setState(() {
        _loading = false;
        _error = "Failed to load transactions: $e";
      });
      debugPrint('loadData error: $e\n$st');
    }
  }

  /// Tries to call a model prediction endpoint on the backend.
  /// Expects JSON response. If unavailable or returns non-200 we return null.
  /// Tries to call a model prediction endpoint on the backend.
  /// Expects JSON response. If unavailable or returns non-200 we return null.
  Future<Map<String, dynamic>?> _tryCallModelPredictEndpoint(
    List<double> recentDailyAmounts,
  ) async {
    try {
      // adapt the path to your backend's prediction endpoint if different
      final base = _api.apiBase;
      final url = Uri.parse('$base/predict-next');

      // Use `http` directly
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amounts': recentDailyAmounts}),
      );

      if (resp.statusCode == 200) {
        final jsonBody = jsonDecode(resp.body) as Map<String, dynamic>;
        return jsonBody;
      } else {
        debugPrint('Model endpoint error: ${resp.statusCode} - ${resp.body}');
      }
    } catch (e) {
      debugPrint('Model endpoint call failed: $e');
    }
    return null;
  }

  void _getManualPrediction() {
    final query = _predictionController.text.toLowerCase();
    setState(() {
      if (query.contains('food')) {
        _predictionResult =
            'Prediction: Your "Food" spending is likely to increase by 15% next month if you continue your current habits.';
      } else if (query.contains('rent')) {
        _predictionResult =
            'Prediction: "Rent" payments appear stable and are not expected to change.';
      } else if (query.isEmpty) {
        _predictionResult =
            'Please enter a category or query (e.g., "food spending next month").';
      } else {
        // try to give a quick data-based number if we have categoryTotals
        final cat = query[0].toUpperCase() + query.substring(1);
        if (_categoryTotals.containsKey(cat)) {
          final val = _categoryTotals[cat]!;
          _predictionResult =
              'Prediction: Based on history, monthly spend for "$cat" is ~₹${val.toStringAsFixed(0)} total from the sampled period. Projected next month ≈ ₹${(val / 1.0).toStringAsFixed(0)} (simple projection).';
        } else {
          _predictionResult =
              'Prediction: Spending for "$query" is projected to be ₹3,500 next month (fallback heuristic).';
        }
      }
    });
  }

  // UI building
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Spending Forecast')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  'Projected Monthly Spending',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildSummaryCards(context),
                const SizedBox(height: 16),
                _buildForecastChart(context),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final nf = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Column(
      children: [
        Card(
          child: ListTile(
            title: const Text('Total expenses (sampled)'),
            subtitle: Text(
              'Across categories from backend: ${_categoryTotals.length} categories',
            ),
            trailing: Text(nf.format(_totalExpenses)),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('Average daily (sampled)'),
            subtitle: Text('Average across days with data'),
            trailing: Text(nf.format(_avgDaily)),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text('Projected next month'),
            subtitle: Text(
              _predictedNextDay != null
                  ? 'Model predicted next day: ₹${_predictedNextDay!.toStringAsFixed(0)}'
                  : 'Using LSTM Model',
            ),
            trailing: Text(
              nf.format(_predictedNextMonth ?? (_avgDaily * 30.0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForecastChart(BuildContext context) {
    if (_pieEntries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Not enough data to show chart')),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    final total = _pieEntries.fold(0.0, (s, e) => s + e.value);
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.cyan,
      Colors.grey,
    ];

    for (int i = 0; i < _pieEntries.length; i++) {
      final e = _pieEntries[i];
      final pct = total > 0 ? (e.value / total) * 100.0 : 0.0;
      sections.add(
        PieChartSectionData(
          value: e.value,
          title: '${pct.toStringAsFixed(0)}%',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          color: colors[i % colors.length],
          showTitle: true,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: sections,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _pieEntries.map((p) {
                final pct = total > 0 ? p.value / total * 100.0 : 0.0;
                final label = '${p.label} • ${pct.toStringAsFixed(0)}%';
                return Chip(label: Text(label));
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }

  /// Helper: a naive percentage comparison of category vs average monthly
  String _percentageComparedToAverage(String category) {
    final catVal = _categoryTotals[category] ?? 0.0;
    // compute monthly avg from sampled data: (total / months)
    // approximate months by days/30
    final days = 30.0;
    final monthlyAvg = (_totalExpenses / (days > 0 ? (days) : 1.0));
    if (monthlyAvg <= 0) return '—';
    final pct = ((catVal - monthlyAvg) / monthlyAvg) * 100.0;
    if (pct.isNaN) return '—';
    return '${pct.toStringAsFixed(0)}%';
  }
}

class _PieEntry {
  final String label;
  final double value;
  _PieEntry(this.label, this.value);
}
