// ===========================================================
// [6] DebtEditScreen — Sửa thông tin khoản nợ
// ===========================================================
// Trách nhiệm:
//   • Cho phép sửa 3 field: personName, dueDate, note
//   • KHÔNG cho sửa: totalAmount, debtType (backend từ chối)
//   • Validate client-side trước khi gọi API
//
// Layout:
//   • AppBar: "← Sửa khoản nợ" + nút Lưu (disabled khi đang gửi)
//   • Form:
//     - TextField: Tên người vay/cho vay (required)
//     - DatePicker: Ngày hẹn trả (nullable)
//     - TextField: Ghi chú (nullable)
//
// Flow:
//   1. initState → đổ dữ liệu từ currentDebt vào các controller
//   2. Tap Lưu → validate → provider.updateDebt() → pop(true)
//   3. Tap X ngày hẹn → xóa ngày (set null)
//
// Lỗi từ server:
//   • "Tên người liên quan không được để trống." (400)
//   • "Tên người liên quan không được quá 200 ký tự." (400)
//   • "Ghi chú không được quá 500 ký tự." (400)
//
// Gọi từ:
//   • DebtDetailScreen → push khi user tap icon ✏️
// ===========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/debt_update_request.dart';
import '../providers/debt_provider.dart';

class DebtEditScreen extends StatefulWidget {

  final int debtId;    // ID khoản nợ cần sửa
  final bool debtType; // false=CẦN TRẢ, true=CẦN THU — dùng cho label UI

  const DebtEditScreen({
    super.key,
    required this.debtId,
    required this.debtType,
  });

  @override
  State<DebtEditScreen> createState() => _DebtEditScreenState();
}

class _DebtEditScreenState extends State<DebtEditScreen> {

  // =============================================
  // [6.1] STATE
  // =============================================

  final _formKey = GlobalKey<FormState>();                // key validate form
  final _nameController    = TextEditingController();     // controller tên người vay/cho vay
  final _noteController    = TextEditingController();     // controller ghi chú
  DateTime? _selectedDueDate;                             // ngày hẹn trả đã chọn (null = không đặt hạn)

  // =============================================
  // [6.2] LIFECYCLE
  // =============================================

  @override
  void initState() {
    super.initState();
    // Đổ dữ liệu hiện tại từ currentDebt vào form
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillForm());
  }

  @override
  void dispose() {
    _nameController.dispose();    // giải phóng controller tránh memory leak
    _noteController.dispose();
    super.dispose();
  }

  // =============================================
  // [6.3] HELPERS
  // =============================================

  // Đổ dữ liệu từ provider vào form khi màn hình khởi tạo
  void _prefillForm() {
    final debt = context.read<DebtProvider>().currentDebt;
    if (debt == null) return;

    _nameController.text = debt.personName;
    _noteController.text = debt.note ?? '';
    setState(() {
      _selectedDueDate = debt.dueDate; // null nếu chưa đặt hạn
    });
  }

  // Mở DatePicker để chọn ngày hẹn trả
  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    // [FIX] Nếu dueDate cũ đã quá khứ → dùng now+30 ngày làm initialDate
    // tránh Flutter crash khi initialDate < firstDate
    final safeInitial = (_selectedDueDate != null && _selectedDueDate!.isAfter(now))
        ? _selectedDueDate!
        : now.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      // Hạn trả phải là tương lai — không chọn quá khứ
      firstDate: now,
      lastDate: DateTime(2030, 12, 31),
      helpText: 'Chọn ngày hẹn trả',
      confirmText: 'Xác nhận',
      cancelText: 'Hủy',
    );

    if (picked != null) {
      // Gắn giờ cuối ngày (23:59:59) để khớp backend
      setState(() {
        _selectedDueDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  // Xóa ngày hẹn đã chọn → backend nhận null
  void _clearDueDate() {
    setState(() => _selectedDueDate = null);
  }

  // =============================================
  // [6.4] SAVE
  // =============================================

  Future<void> _save() async {
    // Bước 1: Validate form (tên không được trống)
    if (!_formKey.currentState!.validate()) return;

    // Bước 1.5: Confirm trước khi lưu — tránh bấm nhầm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Xác nhận sửa', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc muốn cập nhật khoản nợ này?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Bước 2: Build request — chỉ 3 field được phép sửa
    // [NOTE] dueDate null → backend @NotNull tự trả lỗi "Vui lòng chọn ngày hẹn trả cho khoản nợ."
    final request = DebtUpdateRequest(
      personName: _nameController.text.trim(),
      dueDate: _selectedDueDate,
      note: _noteController.text.trim().isEmpty
          ? null                           // gửi null nếu trống
          : _noteController.text.trim(),
    );

    // Bước 3: Gọi provider (không gọi Service trực tiếp từ Screen)
    final success =
        await context.read<DebtProvider>().updateDebt(widget.debtId, request);

    // Bước 4: Xử lý kết quả
    if (!mounted) return; // [IMPORTANT] check mounted sau await
    if (success) {
      // Thành công → pop(true) báo DebtDetailScreen biết cần reload
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debt update successful'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Thất bại → hiện lỗi từ server dạng SnackBar
      final error = context.read<DebtProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Update failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =============================================
  // [6.5] BUILD
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Consumer<DebtProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.debtType ? 'Modify the loan' : 'Modify the debt',
            ),
            actions: [
              // Nút Lưu trên AppBar — disable khi đang gửi
              TextButton(
                onPressed: provider.isSaving ? null : _save,
                child: provider.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text(
                        'Lưu',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),

          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ----- Thông báo giới hạn sửa -----
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16,
                          color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Only names, appointment dates, and notes can be edited.\n'
                          'The amount changes throughout the transaction.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                ),

                // ----- [Field 1] Tên người vay/cho vay -----
                const Text(
                  'Name of person involved *',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: widget.debtType
                        ? 'Example: Friend A, Khoa...'
                        : 'For example: VPBank, Mr. Hung...',
                    prefixIcon:
                        const Icon(Icons.person_outline, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      // Khớp với validate backend: @NotBlank
                      return 'The name of the person involved cannot be left blank.';
                    }
                    if (value.trim().length > 200) {
                      // Khớp với validate backend: @Size(max=200)
                      return 'The name of the person involved must not exceed 200 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ----- [Field 2] Ngày hẹn trả -----
                const Text(
                  'Delivery date',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedDueDate != null
                                // Hiện ngày đã chọn
                                ? '${_selectedDueDate!.day.toString().padLeft(2, '0')}/'
                                    '${_selectedDueDate!.month.toString().padLeft(2, '0')}/'
                                    '${_selectedDueDate!.year}'
                                // Chưa chọn → placeholder
                                : 'No payment deadline.',
                            style: TextStyle(
                              color: _selectedDueDate != null
                                  ? null
                                  : Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ),
                        // Nút X để xóa ngày đã chọn
                        if (_selectedDueDate != null)
                          GestureDetector(
                            onTap: _clearDueDate,
                            child: Icon(Icons.close,
                                size: 18, color: Colors.grey[500]),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ----- [Field 3] Ghi chú -----
                const Text(
                  'Ghi chú',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  maxLength: 500, // Khớp backend @Size(max=500)
                  decoration: InputDecoration(
                    hintText: 'Examples: Car loan, tuition fees...',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.notes, size: 20),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 30),

                // ----- Nút Lưu chính (bottom) -----
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: provider.isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: provider.isSaving
                        ? const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)
                        : const Text('Save',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
