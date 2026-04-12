import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';

import '../../../core/constants/app_constants.dart';
import '../providers/event_provider.dart';
import '../models/event_response.dart';
import '../models/event_update_request.dart';

// Import IconPicker
import '../../category/screens/icon_picker_screen.dart';

class EditEventScreen extends StatefulWidget {
  final EventResponse event;

  const EditEventScreen({super.key, required this.event});

  @override
  State<EditEventScreen> createState() => EditEventScreenState();
}

class EditEventScreenState extends State<EditEventScreen> {
  late TextEditingController _nameController;
  DateTime? _endDate;
  final String _currency = 'VND';
  bool _isSaving = false;

  /// URL dùng để hiển thị preview và gửi về server (đồng bộ với SavingGoal)
  String? _selectedIconUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event.eventName);
    _endDate = widget.event.endDate;

    /// Khởi tạo giá trị icon từ dữ liệu hiện có của sự kiện
    _selectedIconUrl = widget.event.eventIconUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ================= ICON PICKER LOGIC (Giống SavingGoal) =================
  void _openIconPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const IconPickerScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        // Nhận trực tiếp URL từ IconPicker giống SavingGoal
        _selectedIconUrl = result.url;
      });
    }
  }

  // ================= DATE PICKER =================
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.greenAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1C1C1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) setState(() => _endDate = picked);
  }

  // ================= UPDATE LOGIC =================
  Future<void> _update() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError("Tên sự kiện không được để trống");
      return;
    }
    if (_endDate == null) {
      _showError("Vui lòng chọn ngày kết thúc");
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);

    // Đóng gói dữ liệu gửi về Server
    final request = EventUpdateRequest(
      eventName: name,
      endDate: _endDate!,
      currencyCode: _currency,
      eventIconUrl: _selectedIconUrl, // Gửi Full URL Cloudinary
    );

    final provider = Provider.of<EventProvider>(context, listen: false);
    final success = await provider.update(widget.event.id, request);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      _showError(provider.errorMessage ?? "Update failed");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
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
        title: const Text("Edit Event",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _update,
            child: _isSaving
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.greenAccent))
                : const Text("Done",
                style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // --- ICON PICKER PREVIEW (Đã đồng bộ dùng IconHelper) ---
            Center(
              child: GestureDetector(
                onTap: _openIconPicker,
                child: Stack(
                  children: [
                    IconHelper.buildCircleAvatar(
                      iconUrl: _selectedIconUrl,
                      radius: 48,
                      backgroundColor: const Color(0xFF1C1C1E),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: Colors.blueAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // --- INPUT FORM GROUP ---
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                      decoration: const InputDecoration(
                        labelText: "Event Name",
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Divider(color: Color(0xFF2C2C2E), thickness: 1, height: 1),

                  _buildListTile(
                    icon: Icons.calendar_month_rounded,
                    iconColor: Colors.redAccent,
                    title: "End Date",
                    trailing: Text(
                      _endDate == null
                          ? "Select"
                          : DateFormat('dd/MM/yyyy').format(_endDate!),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    onTap: _pickDate,
                  ),
                  const Divider(color: Color(0xFF2C2C2E), thickness: 1, height: 1),

                  _buildListTile(
                    icon: Icons.currency_exchange,
                    iconColor: Colors.orangeAccent,
                    title: "Currency",
                    trailing: Text(_currency,
                        style: const TextStyle(color: Colors.grey, fontSize: 16)),
                    onTap: null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Created at: ${widget.event.beginDate != null ? DateFormat('dd/MM/yyyy').format(widget.event.beginDate!) : 'Unknown'}",
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
            trailing,
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}