// lib/widgets/analysis_chart.dart
// ignore_for_file: dead_code, unnecessary_type_check

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../services/expenses_api_service.dart';

class AnalysisChart extends StatefulWidget {
  final ExpensesApiService api;
  final String period; // string only for label; we fetch all transactions

  const AnalysisChart({super.key, required this.api, required this.period});

  @override
  State<AnalysisChart> createState() => _AnalysisChartState();
}

class _AnalysisChartState extends State<AnalysisChart> {
  bool _loading = true;
  String? _error;
  Map<String, double> _totals = {};
  double _grandTotal = 0.0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _totals = {};
      _grandTotal = 0.0;
      _count = 0;
    });

    try {
      // ---- KEEP YOUR LOGIC AS-IS ----
      String? nextToken;
      final Map<String, double> totals = {};
      double grand = 0.0;
      int count = 0;

      do {
        final resp = await widget.api.listExpenses(
          limit: 200,
          nextToken: nextToken,
        );

        // Normalize resp -> List<dynamic> items safely
        List<dynamic> itemsList = <dynamic>[];
        if (resp is Map<String, dynamic>) {
          final maybeItems = resp['items'];
          if (maybeItems is List) itemsList = maybeItems;
        } else if (resp is List) {
          itemsList = resp as List;
        }

        for (final raw in itemsList) {
          try {
            if (raw == null || raw is! Map<String, dynamic>) continue;
            // ignore: unnecessary_cast
            final m = raw as Map<String, dynamic>;

            final itemType = (m['itemType'] ?? '').toString().toUpperCase();
            if (itemType != 'TRANSACTION') continue;
            final status = (m['status'] ?? '').toString().toLowerCase();
            if (status == 'deleted') continue;

            final direction = (m['direction'] ?? 'expense')
                .toString()
                .toLowerCase();
            if (direction != 'expense') continue; // only count expenses

            final category = (m['category'] ?? 'Other').toString();

            double amount = 0.0;
            final rawAmt = m['amount'];
            if (rawAmt is num)
              amount = rawAmt.toDouble();
            else if (rawAmt is String)
              amount = double.tryParse(rawAmt) ?? 0.0;

            if (amount <= 0) continue;

            totals[category] = (totals[category] ?? 0.0) + amount;
            grand += amount;
            count += 1;
          } catch (_) {
            continue;
          }
        }

        nextToken = (resp is Map<String, dynamic> && resp['nextToken'] != null)
            ? resp['nextToken'].toString()
            : null;
      } while (nextToken != null && nextToken.isNotEmpty);

      setState(() {
        _totals = totals;
        _grandTotal = grand;
        _count = count;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Error: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _reload, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_totals.isEmpty || _grandTotal <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 64,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 12),
              Text(
                'Insufficient data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text('No spending data available for this period.'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _reload, child: const Text('Reload')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          final chartSize = isWide
              ? 340.0
              : min(constraints.maxWidth * 0.55, 260.0);

          final sections = _buildSections(_totals);
          final legend = _buildLegend(
            _totals,
            _grandTotal,
            isVertical: !isWide,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Spending Breakdown (${widget.period})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: isWide
                      ? Row(
                          children: [
                            SizedBox(width: 12),
                            SizedBox(
                              width: chartSize,
                              height: chartSize,
                              child: PieChart(
                                PieChartData(
                                  sections: sections,
                                  centerSpaceRadius: chartSize * 0.22,
                                  sectionsSpace: 4,
                                  borderData: FlBorderData(show: false),
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(children: legend),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            SizedBox(
                              height: chartSize,
                              child: PieChart(
                                PieChartData(
                                  sections: sections,
                                  centerSpaceRadius: chartSize * 0.22,
                                  sectionsSpace: 4,
                                  borderData: FlBorderData(show: false),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...legend,
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Total spent: ₹${_grandTotal.toStringAsFixed(2)} • Transactions: $_count',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          );
        },
      ),
    );
  }

  List<PieChartSectionData> _buildSections(Map<String, double> data) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
      Colors.cyan,
      Colors.amber,
    ];
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = data.values.fold<double>(0.0, (a, b) => a + b);
    final rnd = Random(42);

    return List.generate(entries.length, (i) {
      final e = entries[i];
      final value = e.value;
      final pct = total > 0 ? (value / total) * 100.0 : 0.0;
      final color = colors[i % colors.length];
      return PieChartSectionData(
        color: color,
        value: value,
        title: '${pct.toStringAsFixed(1)}%',
        radius: 56 + rnd.nextInt(12).toDouble(),
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        showTitle: true,
      );
    });
  }

  List<Widget> _buildLegend(
    Map<String, double> data,
    double total, {
    required bool isVertical,
  }) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
      Colors.cyan,
      Colors.amber,
    ];

    // compact legend row widget
    Widget legendItem(int idx, MapEntry<String, double> entry) {
      final pct = total > 0 ? (entry.value / total) * 100.0 : 0.0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[idx % colors.length],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis, // prevents vertical wrapping
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Text(
              '₹${entry.value.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (isVertical) {
      return entries.asMap().entries.map((mapEntry) {
        final i = mapEntry.key;
        final e = mapEntry.value;
        return legendItem(i, e);
      }).toList();
    } else {
      // horizontal layout: put items in a Column but grouped compactly
      return entries.asMap().entries.map((mapEntry) {
        final i = mapEntry.key;
        final e = mapEntry.value;
        return legendItem(i, e);
      }).toList();
    }
  }
}
