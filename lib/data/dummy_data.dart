import 'transaction_model.dart';

final List<Transaction> dummyTransactions = [
  Transaction(
    title: 'Salary',
    amount: 50000,
    date: DateTime.now().subtract(const Duration(days: 2)),
    category: 'Income',
    type: TransactionType.income,
  ),
  Transaction(
    title: 'Grocery Shopping',
    amount: 2500,
    date: DateTime.now().subtract(const Duration(days: 3)),
    category: 'Food',
    type: TransactionType.expense,
  ),
  Transaction(
    title: 'Rent',
    amount: 15000,
    date: DateTime.now().subtract(const Duration(days: 4)),
    category: 'Housing',
    type: TransactionType.expense,
  ),
  Transaction(
    title: 'Freelance Project',
    amount: 8000,
    date: DateTime.now().subtract(const Duration(days: 5)),
    category: 'Income',
    type: TransactionType.income,
  ),
  Transaction(
    title: 'Internet Bill',
    amount: 800,
    date: DateTime.now().subtract(const Duration(days: 6)),
    category: 'Bills',
    type: TransactionType.expense,
  ),
  Transaction(
    title: 'Sent to Friend',
    amount: 1000,
    date: DateTime.now().subtract(const Duration(days: 7)),
    category: 'Transfer',
    type: TransactionType.transfer,
  ),
];

final List<String> dummyCategories = [
  'Food',
  'Housing',
  'Bills',
  'Salary',
  'Entertainment',
  'Transport',
  'Health',
  'Other',
];
