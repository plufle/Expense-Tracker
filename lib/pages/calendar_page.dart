// lib/pages/calendar_page.dart
// ignore_for_file: dead_code, unnecessary_type_check, duplicate_ignore

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/expenses_api_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final ExpensesApiService _api = ExpensesApiService(
    apiBase: dotenv.env['API_BASE_URL'] ?? '',
  );

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _loading = true;
  String? _error;

  /// Map of date-only -> list of transaction maps (all non-deleted transactions)
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllTransactions();
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  double _parseAmount(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final sanitized = raw.replaceAll(RegExp(r'[^0-9\.\-]'), '');
      return double.tryParse(sanitized) ?? 0.0;
    }
    return 0.0;
  }

  /// Load transactions from backend and populate _events,
  /// excluding deleted / non-transaction items.
  Future<void> _loadAllTransactions() async {
    setState(() {
      _loading = true;
      _error = null;
      _events.clear();
    });

    try {
      String? nextToken;
      final List<Map<String, dynamic>> all = [];

      do {
        final resp = await _api.listExpenses(limit: 200, nextToken: nextToken);

        // normalize response into a list of maps
        List<dynamic> items = <dynamic>[];
        // ignore: unnecessary_type_check
        if (resp is Map<String, dynamic>) {
          final maybeItems = resp['items'];
          if (maybeItems is List) items = maybeItems;
        } else if (resp is List) {
          items = resp as List;
        }

        for (final raw in items) {
          if (raw is Map<String, dynamic>) {
            all.add(raw);
          } else if (raw is Map) {
            all.add(Map<String, dynamic>.from(raw));
          }
        }

        nextToken = (resp is Map<String, dynamic> && resp['nextToken'] != null)
            ? resp['nextToken'].toString()
            : null;
      } while (nextToken != null && nextToken.isNotEmpty);

      // Populate events map, filtering out "dead" transactions.
      for (final item in all) {
        try {
          // Skip non-transaction or deleted items
          final itemType = (item['itemType'] ?? '').toString().toUpperCase();
          final status = (item['status'] ?? '').toString().toLowerCase();
          if (itemType != 'TRANSACTION') continue;
          if (status == 'deleted') continue;

          // Determine date (try date, timestamp, createdAt)
          String? dateStr;
          if (item['date'] != null)
            dateStr = item['date'].toString();
          else if (item['timestamp'] != null)
            dateStr = item['timestamp'].toString();
          else if (item['createdAt'] != null)
            dateStr = item['createdAt'].toString();

          DateTime date;
          if (dateStr != null) {
            date =
                DateTime.tryParse(dateStr) ??
                DateTime.tryParse(dateStr.replaceAll(' ', 'T')) ??
                DateTime.now();
          } else {
            date = DateTime.now();
          }

          final key = _dateOnly(date);

          // Build a simplified transaction record for listing
          final tx = <String, dynamic>{
            'id': item['expenseId'] ?? item['id'] ?? '',
            'title':
                item['title'] ??
                item['description'] ??
                item['category'] ??
                'Transaction',
            'category': item['category'] ?? 'Other',
            'amount': _parseAmount(item['amount']),
            'raw': item,
            'type':
                item['direction'] ??
                'expense', // Add transaction type (income/expense)
          };

          // append to the full list for the date (this keeps all transactions)
          _events.putIfAbsent(key, () => []).add(tx);
        } catch (_) {
          // ignore malformed items
          continue;
        }
      }

      setState(() {
        _loading = false;
        _error = null;
        _selectedDay = _selectedDay ?? _focusedDay;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final d = _dateOnly(day);
    return _events[d] ?? <Map<String, dynamic>>[];
  }

  /// For the calendar markers we want to show at most one marker per day.
  List<dynamic> _markerForDay(DateTime day) {
    final items = _getEventsForDay(day);
    if (items.isEmpty) return <dynamic>[];
    // return a single marker object (we keep the first transaction as marker payload)
    return [items.first];
  }

  Color _getAmountColor(String type) {
    return type == 'income' ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Calendar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Error: $_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadAllTransactions,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAllTransactions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Card(
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },

                          // Use our marker provider that returns at most one element
                          eventLoader: _markerForDay,

                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),

                          calendarStyle: CalendarStyle(
                            markerDecoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            markersMaxCount: 1, // ensure only one dot visible
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedDay != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Transactions on ${DateFormat.yMMMd().format(_selectedDay!)}",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._getEventsForDay(_selectedDay!).map((tx) {
                          final amount = tx['amount'] ?? 0.0;
                          final title = tx['title'] ?? '';
                          final category = tx['category'] ?? '';
                          final type =
                              tx['type'] ?? 'expense'; // Default to expense

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: Theme.of(context).primaryColor,
                                child: const Icon(
                                  Icons.money,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(title),
                              subtitle: Text(category),
                              trailing: Text(
                                '₹${amount is double ? amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2) : amount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getAmountColor(
                                    type,
                                  ), // Apply color based on type
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        if (_getEventsForDay(_selectedDay!).isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Text(
                              'No transactions for this day.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
