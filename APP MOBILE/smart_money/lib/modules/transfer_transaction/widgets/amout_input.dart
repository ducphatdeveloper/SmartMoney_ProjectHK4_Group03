import 'package:flutter/material.dart';

class AmountInput extends StatelessWidget {
  final TextEditingController controller;

  const AmountInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Amount", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade700),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("VND"),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: "0",
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
