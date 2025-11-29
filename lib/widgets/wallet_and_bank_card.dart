// lib/widgets/wallet_and_bank_card.dart
import 'package:flutter/material.dart';
import '../services/expenses_api_service.dart';
import 'package:intl/intl.dart';

class WalletAndBankCard extends StatefulWidget {
  final ExpensesApiService api;
  const WalletAndBankCard({super.key, required this.api});

  @override
  WalletAndBankCardState createState() => WalletAndBankCardState();
}

class WalletAndBankCardState extends State<WalletAndBankCard> {
  bool _loading = true;
  double _total = 0.0;
  String? _error;

  Future<void> reload() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await widget.api.listExpenses(limit: 200);
      final items =
          (resp['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      double total = 0.0;
      for (var it in items) {
        final itemType = (it['itemType'] ?? '').toString().toUpperCase();
        if (itemType != 'TRANSACTION') continue;
        final status = (it['status'] ?? '').toString().toLowerCase();
        if (status == 'deleted') continue;
        final dir = (it['direction'] ?? 'expense').toString().toLowerCase();
        final amountRaw = it['amount'];
        double amount = 0.0;
        try {
          amount = (amountRaw is num)
              ? amountRaw.toDouble()
              : double.parse(amountRaw.toString());
        } catch (_) {
          amount = 0.0;
        }
        if (dir == 'income')
          total += amount;
        else if (dir == 'expense')
          total -= amount;
      }
      setState(() {
        _total = total;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _fmt(double v) {
    final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return f.format(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.primary,
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NET BALANCE',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _fmt(_total),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
