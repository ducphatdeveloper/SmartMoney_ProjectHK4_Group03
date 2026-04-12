import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';

import '../providers/event_provider.dart';
import '../models/event_create_request.dart';

// Import IconPicker và DTO
import '../../category/models/icon_dto.dart';
import '../../category/screens/icon_picker_screen.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => AddEventScreenState();
}

class AddEventScreenState extends State<AddEventScreen> {
  final _nameController = TextEditingController();
  DateTime? _endDate;
  final String _currency = 'VND';
  bool _isSaving = false;

  /// 🔥 SỬ DỤNG LINK CLOUD TRỰC TIẾP
  /// Gán một icon mặc định từ Cloudinary/Server của bạn
  String? _selectedIconUrl = "https://res.cloudinary.com/drd2hsocc/image/upload/v1774385006/icon_basic_wallet.png";

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ===============================
  // 🎯 ICON PICKER LOGIC
  // ===============================
  void _openIconPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const IconPickerScreen(), // Không cần truyền fileName cũ nếu dùng URL
      ),
    );

    if (result != null && result is IconDto && mounted) {
      setState(() {
        // Lấy trực tiếp URL từ Cloud để hiển thị và lưu trữ
        _selectedIconUrl = result.url;
      });
    }
  }

  // ===============================
  // 🎯 DATE PICKER
  // ===============================
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.greenAccent,
              onPrimary: Colors.black,
              surface: const Color(0xFF1C1C1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) setState(() => _endDate = picked);
  }

  // ===============================
  // 🎯 SAVE ACTION (Gửi Link Cloud)
  // ===============================
  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showError("Tên sự kiện không được để trống");
      return;
    }
    if (_endDate == null) {
      _showError("Vui lòng nhập ngày kết thúc");
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);

    // 🔥 GỬI FULL URL LÊN SERVER
    final request = EventCreateRequest(
      eventName: name,
      endDate: _endDate!,
      currencyCode: _currency,
      eventIconUrl: _selectedIconUrl, // Sử dụng biến chứa link cloud
    );

    final provider = Provider.of<EventProvider>(context, listen: false);
    final success = await provider.create(request);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      _showError(provider.errorMessage ?? "Không thể tạo sự kiện");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "New Event",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent))
                : const Text(
              "Save",
              style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- UI ICON PREVIEW ---
            Center(
              child: GestureDetector(
                onTap: _openIconPicker,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        IconHelper.buildCircleAvatar(
                          iconUrl: _selectedIconUrl, // Hiển thị từ link cloud
                          radius: 45,
                          backgroundColor: const Color(0xFF1C1C1E),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Set Icon",
                      style: TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // --- FORM FIELDS ---
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: "Event Name",
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                        hintText: "Wedding, Vacation, etc.",
                        hintStyle: TextStyle(color: Color(0xFF48484A), fontSize: 14),
                      ),
                    ),
                  ),
                  const Divider(color: Color(0xFF2C2C2E), height: 1),

                  _buildListTile(
                    icon: Icons.calendar_month,
                    color: Colors.redAccent,
                    title: "End Date",
                    trailing: Text(
                      _endDate == null ? "Select Date" : DateFormat('dd/MM/yyyy').format(_endDate!),
                      style: TextStyle(
                        color: _endDate == null ? Colors.grey : Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: _pickDate,
                  ),
                  const Divider(color: Color(0xFF2C2C2E), height: 1),

                  _buildListTile(
                    icon: Icons.payments_outlined,
                    color: Colors.blueAccent,
                    title: "Currency",
                    trailing: const Text(
                      "VND (₫)",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    onTap: null,
                    showArrow: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color color,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
    bool showArrow = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
            trailing,
            if (showArrow) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ]
          ],
        ),
      ),
    );
  }
}