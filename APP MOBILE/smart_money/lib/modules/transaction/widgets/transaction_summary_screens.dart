import 'package:flutter/material.dart';
import 'package:smart_money/modules/Transaction/models/transaction_models.dart';


class TransactionSummary extends StatelessWidget {
  final List<TransactionModel> transactions;

  const TransactionSummary({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final income =
        transactions.where((t) => t.amount > 0).fold(0.0, (s, t) => s + t.amount);

    final expense =
        transactions.where((t) => t.amount < 0).fold(0.0, (s, t) => s + t.amount.abs());

    final balance = income - expense;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _item("Thu", income, Colors.green),
          _item("Chi", expense, Colors.red),
          _item("Còn lại", balance, Colors.blue),
        ],
      ),
    );
  }

  Widget _item(String title, double value, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        Text(
          "${value.toInt()} đ",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
