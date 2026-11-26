import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
enum ExpensesPostingKind { pettyCash, liquidation, disbursement }

String expensesPostingTitle(ExpensesPostingKind kind) {
  switch (kind) {
    case ExpensesPostingKind.pettyCash:
      return 'Petty Cash';
    case ExpensesPostingKind.liquidation:
      return 'Liquidation';
    case ExpensesPostingKind.disbursement:
      return 'Disbursement';
  }
}

InputDecoration _field(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    );

/// Posting screens aligned to office Expenses (API wiring per module comes next).
class ExpensesPostingPage extends StatefulWidget {
  const ExpensesPostingPage({
    super.key,
    required this.api,
    required this.kind,
  });

  final ApiClient api;
  final ExpensesPostingKind kind;

  @override
  State<ExpensesPostingPage> createState() => _ExpensesPostingPageState();
}

class _ExpensesPostingPageState extends State<ExpensesPostingPage> {
  DateTime _transactionDate = DateTime.now();
  final _amountController = TextEditingController(text: '0.00');
  final _referenceController = TextEditingController();
  final _remarksController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _transactionDate = picked);
  }

  void _save() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${expensesPostingTitle(widget.kind)} saved on device — full AP sync with office is coming soon.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = expensesPostingTitle(widget.kind);
  return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Same place as office Expenses → $title.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: _field('Transaction date'),
                    child: Text(
                      '${_transactionDate.year}-${_transactionDate.month.toString().padLeft(2, '0')}-${_transactionDate.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _referenceController,
                  decoration: _field('Reference / voucher no.'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  decoration: _field('Amount'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: _field('Remarks'),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}