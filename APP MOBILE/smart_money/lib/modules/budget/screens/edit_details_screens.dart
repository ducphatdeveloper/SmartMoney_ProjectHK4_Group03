import 'package:flutter/material.dart';
import 'package:smart_money/modules/budget/models/budget_response.dart';

class EditBudgetDetailScreen extends StatefulWidget {
  final BudgetResponse budget;

  const EditBudgetDetailScreen({super.key, required this.budget});

  @override
  State<EditBudgetDetailScreen> createState() => _EditBudgetDetailScreenState();
}

class _EditBudgetDetailScreenState extends State<EditBudgetDetailScreen> {
  late TextEditingController amountCtrl;

  late DateTime startDate;
  late DateTime endDate;

  @override
  void initState() {
    super.initState();

    amountCtrl = TextEditingController(
      text: widget.budget.amount.toInt().toString(),
    );

    startDate = widget.budget.beginDate;

    endDate = widget.budget.endDate;
  }

  void _pickDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
    );

    if (result != null) {
      setState(() {
        startDate = result.start;
        endDate = result.end;
      });
    }
  }

  void _save() {
    final amount = double.tryParse(amountCtrl.text) ?? 0;

    /// ===== VALIDATION =====
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Số tiền phải hợp lệ")),
      );
      return;
    }

    final updated = BudgetResponse(
      id: widget.budget.id,
      amount: amount,
      beginDate: startDate,
      endDate: endDate,
      walletId: widget.budget.walletId,
      walletName: widget.budget.walletName,
      allCategories: widget.budget.allCategories,
      repeating: widget.budget.repeating,
      categories: widget.budget.categories,
      expired: widget.budget.expired,
      spentAmount: widget.budget.spentAmount,
      remainingAmount: widget.budget.remainingAmount,
      dailyShouldSpend: widget.budget.dailyShouldSpend,
      dailyActualSpend: widget.budget.dailyActualSpend,
      projectedSpend: widget.budget.projectedSpend,
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sửa ngân sách")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// ===== AMOUNT =====
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Số tiền mục tiêu"),
          ),

          const SizedBox(height: 12),

          /// ===== DATE RANGE =====
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Thời gian áp dụng"),
            subtitle: Text(
              "${startDate.day}/${startDate.month}/${startDate.year} - "
              "${endDate.day}/${endDate.month}/${endDate.year}",
            ),
            trailing: const Icon(Icons.date_range),
            onTap: _pickDateRange,
          ),


          const SizedBox(height: 24),

          /// ===== SAVE =====
          ElevatedButton(onPressed: _save, child: const Text("Lưu thay đổi")),
        ],
      ),
    );
  }
}
