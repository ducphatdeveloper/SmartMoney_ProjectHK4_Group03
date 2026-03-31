import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/event_provider.dart';
import '../models/event_response.dart';
import '../models/event_update_request.dart';
import '../../category/models/icon_dto.dart';
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
  IconDto? _selectedIcon;

  @override
  void initState() {
    super.initState();
    // Khởi tạo dữ liệu cũ từ object event truyền vào
    _nameController = TextEditingController(text: widget.event.eventName);
    _endDate = widget.event.endDate;

    // Nếu có icon cũ, bạn có thể khởi tạo ở đây (tùy thuộc vào cách bạn lưu IconDto)
    // _selectedIcon = IconDto(fileName: widget.event.eventIconUrl, url: ...);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _openIconPicker() async {
    final result = await Navigator.push<IconDto>(
      context,
      MaterialPageRoute(
        builder: (_) => IconPickerScreen(
          currentIconFileName: _selectedIcon?.fileName ?? widget.event.eventIconUrl,
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
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _endDate = picked);
  }

  Future<void> _update() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return _showError("Event name is required");
    if (_endDate == null) return _showError("Please select end date");
    if (_isSaving) return;

    setState(() => _isSaving = true);

    // Sử dụng EventUpdateRequest để gửi lên server
    final request = EventUpdateRequest(
      eventName: name,
      endDate: _endDate!,
      currencyCode: _currency,
      eventIconUrl: _selectedIcon?.fileName ?? widget.event.eventIconUrl,
    );

    final provider = Provider.of<EventProvider>(context, listen: false);
    final success = await provider.update(widget.event.id!, request);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      // Trả về true và pop sâu 2 lần (hoặc pop về trang list) để cập nhật lại data
      Navigator.pop(context, true);
    } else {
      _showError(provider.errorMessage ?? "Update failed");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
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
      borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(16)) : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF2C2C2E), width: 0.5)),
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
        title: const Text("Edit Event", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.redAccent, fontSize: 15)),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _update,
            child: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                : const Text("Save", style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.w600)),
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
                  // ===== EVENT NAME & ICON =====
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _openIconPicker,
                          child: Container(
                            width: 45, height: 45,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: _selectedIcon != null
                                ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: CachedNetworkImage(
                                imageUrl: _selectedIcon!.url,
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