import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/event_provider.dart';
import '../models/event_create_request.dart';
import '../../category/models/icon_dto.dart'; // Đảm bảo đúng path tới IconDto
import '../../category/screens/icon_picker_screen.dart'; // Đảm bảo đúng path tới IconPicker

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

  // Biến lưu trữ icon đã chọn
  IconDto? _selectedIcon;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Mở màn hình chọn Icon giống bên Category
  void _openIconPicker() async {
    final result = await Navigator.push<IconDto>(
      context,
      MaterialPageRoute(
        builder: (_) => IconPickerScreen(
          currentIconFileName: _selectedIcon?.fileName,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedIcon = result;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now,
      firstDate: now,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.green,
              onPrimary: Colors.white,
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

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return _showError("Event name is required");
    if (_endDate == null) return _showError("Please select end date");
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final request = EventCreateRequest(
      eventName: name,
      endDate: _endDate!,
      currencyCode: _currency,
      eventIconUrl: _selectedIcon?.fileName, // Truyền tên file icon đã chọn
    );

    final provider = Provider.of<EventProvider>(context, listen: false);
    final success = await provider.create(request);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      _showError(provider.errorMessage ?? "An error occurred");
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

  Widget _buildItem({
    required Widget leading,
    required String title,
    VoidCallback? onTap,
    bool showArrow = true,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(16))
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFF2C2C2E), width: 0.5)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
            if (showArrow) const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
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
            "Add Event",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17)
        ),
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.w400)
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
            )
                : const Text(
              "Save",
              style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ===== EVENT NAME & ICON PICKER =====
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Click vào icon để chọn icon mới
                        GestureDetector(
                          onTap: _openIconPicker,
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.withOpacity(0.3))
                            ),
                            child: _selectedIcon != null
                                ? Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: CachedNetworkImage(
                                imageUrl: _selectedIcon!.url,
                                fit: BoxFit.contain,
                                placeholder: (_, __) => const CircularProgressIndicator(strokeWidth: 1),
                                errorWidget: (_, __, ___) => const Icon(Icons.event, color: Colors.blueAccent),
                              ),
                            )
                                : const Icon(Icons.event, color: Colors.blueAccent, size: 26),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: "Event Name",
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF2C2C2E)),

                  // ===== END DATE =====
                  _buildItem(
                    leading: const Icon(Icons.calendar_today, color: Colors.grey, size: 22),
                    title: _endDate == null
                        ? "End Date"
                        : "${_endDate!.day}/${_endDate!.month}/${_endDate!.year}",
                    onTap: _pickDate,
                  ),

                  // ===== CURRENCY =====
                  _buildItem(
                    leading: const Icon(Icons.payments_outlined, color: Colors.grey, size: 22),
                    title: "Currency (VND)",
                    onTap: () {},
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}