import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddSavingGoalScreen extends StatefulWidget {
  const AddSavingGoalScreen({super.key});

  @override
  State<AddSavingGoalScreen> createState() => _AddSavingGoalScreenState();
}

class _AddSavingGoalScreenState extends State<AddSavingGoalScreen> {

  final TextEditingController nameController = TextEditingController();
  final TextEditingController targetController = TextEditingController();
  final TextEditingController currentController = TextEditingController();

  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 30));

  String? selectedImage;

  final images = [
    "🏖️", "🚗", "🏠", "📱", "🎓", "💍", "🎮", "✈️"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Ví tiết kiệm"),
        centerTitle: true,
        backgroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              "LƯU",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          _goalImagePicker(),
          const SizedBox(height: 16),

          _inputCard(
            child: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Tên mục tiêu",
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          _inputCard(
            child: TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Số tiền mục tiêu",
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          _inputCard(
            child: TextField(
              controller: currentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Số tiền hiện tại",
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          _datePicker(),

          const SizedBox(height: 24),

          _previewProgress(),
        ],
      ),
    );
  }

  // ================= IMAGE PICKER =================
  Widget _goalImagePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: images.map((e) {
          final isSelected = selectedImage == e;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedImage = e;
              });
            },
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? Colors.green : Colors.white10,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                e,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================= DATE PICKER =================
  Widget _datePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        children: [
          _dateRow("Bắt đầu", startDate, (date) {
            setState(() => startDate = date);
          }),
          const Divider(),
          _dateRow("Kết thúc", endDate, (date) {
            setState(() => endDate = date);
          }),
        ],
      ),
    );
  }

  Widget _dateRow(String title, DateTime date, Function(DateTime) onPick) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) onPick(picked);
          },
          child: Text(DateFormat('dd/MM/yyyy').format(date)),
        ),
      ],
    );
  }

  // ================= PROGRESS =================
  Widget _previewProgress() {
    final target = double.tryParse(targetController.text) ?? 0;
    final current = double.tryParse(currentController.text) ?? 0;

    final progress = target == 0
        ? 0.0
        : (current / target).clamp(0.0, 1.0).toDouble();


    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tiến độ"),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text("${(progress * 100).toStringAsFixed(0)}%"),
        ],
      ),
    );
  }

  // ================= COMMON =================
  Widget _inputCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _card(),
      child: child,
    );
  }

  BoxDecoration _card() {
    return BoxDecoration(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(16),
    );
  }

  // ================= SAVE =================
  void _save() async {

    // TODO: call API saving goal

    Navigator.pop(context, true);
  }
}
