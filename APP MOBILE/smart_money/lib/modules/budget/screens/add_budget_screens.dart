import 'package:flutter/material.dart';
import 'package:smart_money/modules/budget/models/budget_models.dart'; // Đã sửa thành chữ thường

class AddBudgetScreen extends StatefulWidget {
  const AddBudgetScreen({super.key});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController();

  IconData selectedIcon = Icons.fastfood;
  bool showIcons = false;
  bool isTotal = true;
  bool repeat = false;

  DateTimeRange? range;

  final icons = [
    Icons.fastfood,
    Icons.shopping_cart,
    Icons.directions_bus,
    Icons.movie,
    Icons.home,
    Icons.favorite,
  ];

  void save() {
    final budget = BudgetModel(
      id: DateTime.now().toString(),
      name: nameCtrl.text.isEmpty ? "Ngân sách" : nameCtrl.text,
      icon: selectedIcon,
      amount: double.tryParse(amountCtrl.text) ?? 0,
      startDate: range?.start ?? DateTime.now(),
      endDate: range?.end ?? DateTime.now(),
      categoryId: isTotal ? null : "food",
      repeat: repeat,
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
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Tên ngân sách",
                    border: InputBorder.none,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(child: Icon(selectedIcon)),
                  title: const Text("Chọn biểu tượng"),
                  onTap: () => setState(() => showIcons = !showIcons),
                ),
                if (showIcons)
                  Wrap(
                    spacing: 12,
                    children: icons.map((icon) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedIcon = icon;
                            showIcons = false;
                          });
                        },
                        child: CircleAvatar(child: Icon(icon)),
                      );
                    }).toList(),
                  ),
                const Divider(),
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
              value: isTotal,
              onChanged: (v) => setState(() => isTotal = v),
              title: const Text("Ngân sách tổng"),
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
