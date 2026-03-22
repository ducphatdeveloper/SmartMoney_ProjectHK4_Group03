import 'package:flutter/material.dart';
import 'package:smart_money/modules/budget/models/budget_response.dart';

class AddBudgetScreen extends StatefulWidget {
  const AddBudgetScreen({super.key});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final amountCtrl = TextEditingController();

  bool repeat = false;

  DateTimeRange? range;

  void save() {
    final amount = double.tryParse(amountCtrl.text) ?? 0;
    
    if (amount <= 0 || range == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập số tiền và chọn thời gian")),
      );
      return;
    }

    final budget = BudgetResponse(
      id: DateTime.now().millisecondsSinceEpoch,
      amount: amount,
      beginDate: range!.start,
      endDate: range!.end,
      repeating: repeat,
    );

    Navigator.pop(context, budget);
  }

  Future pickDate() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (result != null) setState(() => range = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thêm ngân sách")),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(onPressed: save, child: const Text("Lưu")),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            child: Column(
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Số tiền",
                    prefixText: "VND ",
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                range == null
                    ? "Chọn thời gian"
                    : "${range!.start.day}/${range!.start.month} - ${range!.end.day}/${range!.end.month}",
              ),
              onTap: pickDate,
            ),
          ),
          const SizedBox(height: 16),
          _card(
            child: SwitchListTile(
              value: repeat,
              onChanged: (v) => setState(() => repeat = v),
              title: const Text("Lặp lại hàng tháng"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
