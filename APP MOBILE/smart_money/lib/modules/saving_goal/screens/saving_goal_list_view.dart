
import 'package:flutter/material.dart';

class SavingGoalListView extends StatelessWidget {
  const SavingGoalListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Mục tiêu tiết kiệm",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _savingItem("Mua xe", 0.2, "20.000.000 đ / 100.000.000 đ"),
        _savingItem("Du lịch", 0.6, "6.000.000 đ / 10.000.000 đ"),
      ],
    );
  }

  Widget _savingItem(String name, double percent, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: percent),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
