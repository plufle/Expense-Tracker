// lib/widgets/budget_section.dart
import 'package:flutter/material.dart';
import '../services/expenses_api_service.dart';

class BudgetSection extends StatefulWidget {
  final ExpensesApiService api;

  // Updated fixed budget categories (Food, Entertainment, Transport, Health, Other)
  static const Map<String, double> defaultBudgets = {
    'Food': 8000,
    'Entertainment': 4000,
    'Transport': 3000,
    'Health': 2000,
    'Other': 1000, // For any other unclassified expenses
  };

  const BudgetSection({super.key, required this.api});

  @override
  BudgetSectionState createState() => BudgetSectionState();
}

class BudgetSectionState extends State<BudgetSection> {
  bool _loading = true;
  String? _error;
  Map<String, double> _spent = {};

  @override
  void initState() {
    super.initState();
    _loadAllTransactions();
  }

  Future<void> reloadMonth() => _loadAllTransactions();

  Future<void> _loadAllTransactions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Call the API to fetch all transactions (without date filtering)
      final resp = await widget.api.listExpenses(
        limit: 500, // You can increase the limit if needed
      );
      final items =
          (resp['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      final Map<String, double> acc = {}; // To accumulate spending by category
      for (var it in items) {
        final itemType = (it['itemType'] ?? '').toString().toUpperCase();
        if (itemType != 'TRANSACTION') continue;
        final status = (it['status'] ?? '').toString().toLowerCase();
        if (status == 'deleted') continue; // Skip deleted transactions

        final category = (it['category'] ?? 'Other').toString();
        final dir = (it['direction'] ?? 'expense').toString().toLowerCase();
        double amt = 0.0;
        try {
          amt = (it['amount'] is num)
              ? (it['amount'] as num).toDouble()
              : double.parse(it['amount'].toString());
        } catch (_) {
          amt = 0.0; // If amount can't be parsed, treat as 0.0
        }

        // Only sum the expenses (not income) and restrict to fixed categories
        if (dir == 'expense' &&
            BudgetSection.defaultBudgets.containsKey(category)) {
          acc[category] = (acc[category] ?? 0.0) + amt;
        }
      }

      setState(() {
        _spent = acc; // Set the accumulated spending data
        _loading = false;
      });
    } catch (e) {
      debugPrint('BudgetSection error: $e');
      setState(() {
        _spent = {};
        _loading = false;
        _error = 'Could not load transactions (server)';
      });
    }
  }

  Widget _buildBudgetCard(
    BuildContext context,
    String category,
    double budget, // Fixed budget for the category
    double spent, {
    bool isOver = false,
    required double progress,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${spent.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}',
                  style: TextStyle(color: isOver ? Colors.red : Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? Colors.red : Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final budgets = BudgetSection.defaultBudgets; // Use the fixed budgets
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monthly Budgets', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        ...budgets.entries.map((entry) {
          final category = entry.key;
          final limit =
              entry.value; // Predefined budget limit for this category
          final spent =
              _spent[category] ?? 0.0; // Amount spent in this category
          final progress = (spent / limit).clamp(
            0.0,
            1.0,
          ); // Progress bar based on the spent amount
          final isOver = spent > limit; // Is the spending over the budget?
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildBudgetCard(
              context,
              category,
              limit, // Fixed budget value
              spent,
              isOver: isOver,
              progress: progress,
            ),
          );
        }).toList(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Info: $_error',
              style: const TextStyle(color: Colors.orange),
            ),
          ),
      ],
    );
  }
}
