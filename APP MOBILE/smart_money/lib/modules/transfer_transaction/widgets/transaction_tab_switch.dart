import 'package:flutter/material.dart';

enum TransactionTab { expense, income, debt }

class TransactionTabSwitch extends StatelessWidget {
  final TransactionTab tab;
  final ValueChanged<TransactionTab> onChanged;

  const TransactionTabSwitch({
    super.key,
    required this.tab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildItem(String text, TransactionTab value) {
      final selected = tab == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? Colors.grey.shade700 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          buildItem("Khoản chi", TransactionTab.expense),
          buildItem("Khoản thu", TransactionTab.income),
          buildItem("Vay/Nợ", TransactionTab.debt),
        ],
      ),
    );
  }
}
