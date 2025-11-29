import 'package:flutter/material.dart';
import '../widgets/wallet_and_bank_card.dart';
import '../widgets/budget_section.dart';
import '../widgets/recent_transactions.dart';
import '../widgets/financial_news.dart';
import '../widgets/add_transaction_form.dart';
import '../services/expenses_api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = ExpensesApiService(apiBase: dotenv.env['API_BASE_URL'] ?? '');
  final _recentKey = GlobalKey<RecentTransactionsState>();
  final _walletKey = GlobalKey<WalletAndBankCardState>();
  final _budgetKey = GlobalKey<BudgetSectionState>();

  Future<void> _openAddTransaction() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AddTransactionForm(api: _api),
      ),
    );

    if (created == true) {
      _recentKey.currentState?.reload();
      _walletKey.currentState?.reload();
      _budgetKey.currentState?.reloadMonth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTransaction,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          WalletAndBankCard(key: _walletKey, api: _api),
          const SizedBox(height: 20),
          BudgetSection(key: _budgetKey, api: _api),
          const SizedBox(height: 20),
          RecentTransactions(key: _recentKey, api: _api),
          const SizedBox(height: 20),
          const FinancialNews(),
        ],
      ),
    );
  }
}
