import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class AddSavingGoalScreen extends StatefulWidget {
  const AddSavingGoalScreen({super.key});

  @override
  State<AddSavingGoalScreen> createState() => _AddSavingGoalScreenState();
}

class _AddSavingGoalScreenState extends State<AddSavingGoalScreen> {
  IconData selectedIcon = Icons.savings;
  String currency = "VND";
  bool notify = false;
  DateTime? endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tạo ví tiết kiệm"),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Save saving goal
            },
            child: const Text(
              "LƯU",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _nameAndIcon(),
          const SizedBox(height: 16),
          _currencyPicker(),
          const SizedBox(height: 16),
          _targetAmount(),
          const SizedBox(height: 16),
          _currentAmount(),
          const SizedBox(height: 16),
          _endDatePicker(),
          const SizedBox(height: 16),
          _notifySwitch(),
        ],
      ),
    );
  }

  // ===== Widgets =====

  Widget _nameAndIcon() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showIconPicker,
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.orange.withOpacity(0.15),
              child: Icon(selectedIcon, color: Colors.orange),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Tên mục tiêu",
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _cardDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currency,
          items: const [
            DropdownMenuItem(value: "VND", child: Text("VND - Việt Nam Đồng")),
            DropdownMenuItem(value: "USD", child: Text("USD - Đô la Mỹ")),
            DropdownMenuItem(value: "EUR", child: Text("EUR - Euro")),
          ],
          onChanged: (value) {
            setState(() {
              currency = value!;
            });
          },
        ),
      ),
    );
  }

  Widget _targetAmount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _cardDecoration(),
      child: TextField(
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: "Số tiền mục tiêu",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _currentAmount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _cardDecoration(),
      child: TextField(
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: "Số tiền hiện có",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _endDatePicker() {
    return InkWell(
      onTap: _pickEndDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 16),
            Text(
              endDate == null
                  ? "Chọn ngày kết thúc"
                  : intl.DateFormat('dd/MM/yyyy').format(endDate!),
              style: TextStyle(
                color: endDate == null ? Colors.grey : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifySwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _cardDecoration(),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text("Thông báo"),
        subtitle: const Text("Nhắc nhở khi gần tới ngày kết thúc"),
        value: notify,
        onChanged: (value) {
          setState(() {
            notify = value;
          });
        },
      ),
    );
  }

  // ===== Helpers =====

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(16),
    );
  }

  void _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 10),
    );

    if (date != null) {
      setState(() {
        endDate = date;
      });
    }
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final icons = [
          Icons.savings,
          Icons.home,
          Icons.directions_car,
          Icons.flight,
          Icons.school,
          Icons.shopping_bag,
          Icons.favorite,
        ];

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: icons.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemBuilder: (_, index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedIcon = icons[index];
                });
                Navigator.pop(context);
              },
              child: CircleAvatar(
                backgroundColor: Colors.orange.withOpacity(0.15),
                child: Icon(icons[index], color: Colors.orange),
              ),
            );
          },
        );
      },
    );
  }
}
