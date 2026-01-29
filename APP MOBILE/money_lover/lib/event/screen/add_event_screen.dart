import 'package:flutter/material.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  IconData _selectedIcon = Icons.celebration;
  bool _showIconPicker = false;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;

  final List<IconData> _icons = [
    Icons.celebration,
    Icons.flight,
    Icons.cake,
    Icons.shopping_bag,
    Icons.favorite,
    Icons.sports_soccer,
    Icons.home,
    Icons.school,
  ];

  // ================= DATE PICKER =================
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
    }
  }

  String get _dateText {
    if (_startDate == null || _endDate == null) {
      return "Chọn thời gian";
    }
    return "${_startDate!.day}/${_startDate!.month}/${_startDate!.year}"
        " - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}";
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Tạo sự kiện"),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("LƯU", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== EVENT NAME =====
          _card(
            title: "Tên sự kiện",
            child: TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Nhập tên sự kiện",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),

          // ===== ICON PICKER (COLLAPSE) =====
          _card(
            title: "Biểu tượng",
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showIconPicker = !_showIconPicker;
                    });
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.green.withOpacity(0.2),
                        child: Icon(_selectedIcon, color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Chọn biểu tượng",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      Icon(
                        _showIconPicker ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),

                if (_showIconPicker) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _icons.map((icon) {
                      final selected = icon == _selectedIcon;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIcon = icon;
                            _showIconPicker = false;
                          });
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.green.withOpacity(0.2)
                                : const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: selected ? Colors.green : Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // ===== DATE (COMPACT) =====
          GestureDetector(
            onTap: _pickDateRange,
            child: _card(
              title: "Thời gian",
              child: Row(
                children: [
                  const Icon(Icons.date_range, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _dateText,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),

          // ===== BUDGET =====
          _card(
            title: "Ngân sách",
            child: TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "0 đ",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),

          // ===== ACTIVE =====
          _card(
            title: "Kích hoạt sự kiện",
            child: Switch(
              value: _isActive,
              activeThumbColor: Colors.green,
              onChanged: (v) {
                setState(() => _isActive = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= CARD =================
  Widget _card({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
