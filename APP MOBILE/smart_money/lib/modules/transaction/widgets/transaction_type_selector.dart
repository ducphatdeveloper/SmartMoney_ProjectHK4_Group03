// ===========================================================
// [3.1] TransactionTypeSelector — Widget 3 tab chọn loại giao dịch
// ===========================================================
// Dùng ở: TransactionCreateScreen, TransactionEditScreen
// Hiển thị: 3 tab "Khoản chi" | "Khoản thu" | "Vay/Nợ"
// Tab active: nền xanh lá (#4CAF50), chữ trắng
// Tab inactive: trong suốt, viền xám nhạt, chữ xám
// Tham số:
//   • selectedType: 'expense' | 'income' | 'debt' — tab đang chọn
//   • onChanged: callback khi user đổi tab → Screen cha xử lý reset category
//   • showDebtTab: true để hiện tab Vay/Nợ, false nếu ví là SavingGoal
// ===========================================================

import 'package:flutter/material.dart';

class TransactionTypeSelector extends StatelessWidget {

  final String selectedType;             // tab đang chọn: 'expense' | 'income' | 'debt'
  final ValueChanged<String> onChanged;  // callback khi user đổi tab
  final bool showDebtTab;                // hiện tab Vay/Nợ hay không (ẩn nếu SavingGoal)

  const TransactionTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
    this.showDebtTab = true,
  });

  @override
  Widget build(BuildContext context) {
    // Danh sách các tab — ẩn Vay/Nợ nếu showDebtTab = false
    final tabs = <Map<String, String>>[
      {'label': 'Expense', 'value': 'expense'},
      {'label': 'Income', 'value': 'income'},
      if (showDebtTab) {'label': 'Debt', 'value': 'debt'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = selectedType == tab['value']; // tab đang chọn hay không

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tab['value']!), // gọi callback về Screen cha
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  // Nền xanh lá nếu đang chọn, trong suốt nếu không
                  color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  // Viền xám nếu không chọn
                  border: isSelected ? null : Border.all(color: Colors.grey.shade600),
                ),
                alignment: Alignment.center,
                child: Text(
                  tab['label']!,
                  style: TextStyle(
                    // Chữ trắng nếu đang chọn, xám nếu không
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

