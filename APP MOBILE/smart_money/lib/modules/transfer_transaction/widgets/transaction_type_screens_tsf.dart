import 'package:flutter/material.dart';

enum TransactionTab { expense, income, transfer }

class TransactionTypeTab extends StatelessWidget {
  final TransactionTab selected;
  final Function(TransactionTab) onChanged;

  const TransactionTypeTab({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: TransactionTab.values.map((type) {
        final isActive = selected == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? Colors.green : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                _label(type),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.green : Colors.grey,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _label(TransactionTab type) {
    switch (type) {
      case TransactionTab.expense:
        return "Expense";
      case TransactionTab.income:
        return "Income";
      case TransactionTab.transfer:
        return "Transfer";
    }
  }
}
