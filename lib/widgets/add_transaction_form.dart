import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/expenses_api_service.dart';
import '../data/transaction_model.dart';
import '../data/dummy_data.dart';

class AddTransactionForm extends StatefulWidget {
  final ExpensesApiService api;
  const AddTransactionForm({super.key, required this.api});

  @override
  AddTransactionFormState createState() => AddTransactionFormState();
}

class AddTransactionFormState extends State<AddTransactionForm> {
  final _formKey = GlobalKey<FormState>();
  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  final _dateController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat.yMMMd().format(_selectedDate);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        _dateController.text = DateFormat.yMMMd().format(_selectedDate);
      });
    }
  }

  void _onTypeChanged(TransactionType newType) {
    setState(() {
      _selectedType = newType;
      if (_selectedType == TransactionType.income) {
        if (dummyCategories.contains('Salary')) _selectedCategory = 'Salary';
      } else {
        _selectedCategory = null;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amountText = _amountController.text.trim();
    double amount;
    try {
      amount = double.parse(amountText);
    } catch (_) {
      setState(() {
        _error = 'Enter a valid amount';
      });
      return;
    }
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      setState(() {
        _error = 'Please select a category';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final dateIso = DateFormat('yyyy-MM-dd').format(_selectedDate);
      await widget.api.createExpense(
        amount: amount,
        category: _selectedCategory!,
        date: dateIso,
        description: _descriptionController.text.trim(),
        account: 'Cash',
        direction: _selectedType == TransactionType.income
            ? 'income'
            : 'expense',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        // Make the entire form scrollable
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add Transaction',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Expense'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Income'),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (s) => _onTypeChanged(s.first),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines:
                      null, // Allows the text field to grow based on content.
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: Icon(Icons.money),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter amount' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                        value: _selectedCategory,
                        items: dummyCategories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Select category' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: _pickDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Add Transaction'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
