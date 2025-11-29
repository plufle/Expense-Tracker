// lib/widgets/recent_transactions.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/expenses_api_service.dart';

class RecentTransactions extends StatefulWidget {
  final ExpensesApiService api;
  final int limit;
  const RecentTransactions({super.key, required this.api, this.limit = 4});

  @override
  RecentTransactionsState createState() => RecentTransactionsState();
}

class RecentTransactionsState extends State<RecentTransactions> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await widget.api.listExpenses(limit: widget.limit);
      final rawItems = (resp['items'] as List<dynamic>?) ?? [];
      final items = rawItems.cast<Map<String, dynamic>>().where((m) {
        final itemType = (m['itemType'] ?? '').toString().toUpperCase();
        final hasAmount =
            m.containsKey('amount') &&
            m['amount'] != null &&
            m['amount'].toString().trim().isNotEmpty;
        final status = (m['status'] ?? '').toString().toLowerCase();
        return itemType == 'TRANSACTION' && hasAmount && status != 'deleted';
      }).toList();
      final limited = items.take(widget.limit).toList();
      setState(() {
        _items = limited;
        _loading = false;
      });
    } catch (e, st) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      debugPrint('Failed to load recent transactions: $e\n$st');
    }
  }

  String _formatAmount(dynamic a) {
    try {
      final n = (a is num) ? a : double.parse(a.toString());
      final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
      return f.format(n.abs());
    } catch (_) {
      return a?.toString() ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Transactions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Column(
            children: [
              Text('Error: $_error', style: const TextStyle(color: Colors.red)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          )
        else if (_items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('No recent transactions'),
            ),
          )
        else
          Card(
            child: Column(
              children: _items.map((tx) {
                final dir = (tx['direction'] ?? 'expense')
                    .toString()
                    .toLowerCase();
                final isIncome = dir == 'income';
                final color = isIncome ? Colors.green : Colors.red;
                final title = (tx['description']?.toString().isNotEmpty == true)
                    ? tx['description'].toString()
                    : (tx['category']?.toString() ?? 'Transaction');
                final subtitle = tx['category']?.toString() ?? '';
                final dateStr =
                    tx['date']?.toString() ??
                    (tx['timestamp']?.toString() ?? '');
                final amountText =
                    '${isIncome ? '+' : '-'}${_formatAmount(tx['amount'])}';
                return ListTile(
                  leading: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: color,
                  ),
                  title: Text(title),
                  subtitle: Text('$subtitle • $dateStr'),
                  trailing: Text(
                    amountText,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
