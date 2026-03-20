import 'package:flutter/material.dart';
import 'package:smart_money/modules/budget/models/budget_models.dart'; // Đã sửa thành chữ thường

class EditBudgetDetailScreen extends StatefulWidget {
  final BudgetModel budget;

  const EditBudgetDetailScreen({super.key, required this.budget});

  @override
  State<EditBudgetDetailScreen> createState() => _EditBudgetDetailScreenState();
}

class _EditBudgetDetailScreenState extends State<EditBudgetDetailScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController amountCtrl;
  late TextEditingController noteCtrl;

  late String categoryId;
  late DateTime startDate;
  late DateTime endDate;

  @override
  void initState() {
    super.initState();

    nameCtrl = TextEditingController(text: widget.budget.name);
    amountCtrl = TextEditingController(
      text: widget.budget.amount.toInt().toString(),
    );
    noteCtrl = TextEditingController(text: widget.budget.note ?? "");

    /// 🔥 FIX NULL
    categoryId =
        (widget.budget.categoryId != null &&
            widget.budget.categoryId!.isNotEmpty)
        ? widget.budget.categoryId!
        : "food";

    startDate = widget.budget.startDate ?? DateTime.now();

    endDate =
        widget.budget.endDate ?? DateTime.now().add(const Duration(days: 30));
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

    /// ===== 2️⃣ VALIDATION =====
    if (nameCtrl.text.trim().isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tên & số tiền phải hợp lệ")),
      );
      return;
    }

    final updated = widget.budget.copyWith(
      name: nameCtrl.text.trim(),
      amount: amount,
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
      note: noteCtrl.text.trim(),
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
          /// ===== NAME =====
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: "Tên ngân sách"),
          ),

          const SizedBox(height: 12),

          /// ===== AMOUNT =====
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Số tiền mục tiêu"),
          ),

          const SizedBox(height: 12),

          /// ===== CATEGORY =====
          DropdownButtonFormField<String>(
            value: categoryId,
            items: const [
              DropdownMenuItem(value: "food", child: Text("Ăn uống")),
              DropdownMenuItem(value: "shopping", child: Text("Mua sắm")),
              DropdownMenuItem(value: "travel", child: Text("Du lịch")),
            ],
            onChanged: (v) => setState(() => categoryId = v!),
            decoration: const InputDecoration(labelText: "Danh mục"),
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

          const SizedBox(height: 12),

          /// ===== NOTE =====
          TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: "Ghi chú"),
          ),

          const SizedBox(height: 24),

          /// ===== SAVE =====
          ElevatedButton(onPressed: _save, child: const Text("Lưu thay đổi")),
        ],
      ),
    );
  }
}
