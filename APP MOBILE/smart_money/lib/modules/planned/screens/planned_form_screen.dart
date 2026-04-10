// ===========================================================
// [6] PlannedFormScreen — Form tạo/sửa giao dịch định kỳ & hóa đơn
// ===========================================================
// Layout:
//   • AppBar: nút × (đóng) + tiêu đề + nút LƯU (xanh)
//   • [1] Chọn ví (Dropdown)
//   • [2] Nhập số tiền (TextField format realtime)
//   • [3] Chọn danh mục (tap → CategoryListScreen)
//   • [3.5] Chọn khoản nợ (chỉ hiện khi category là 19/20/21/22)
//   • [4] Ghi chú (TextField)
//   • [5] Lịch lặp lại (tap → RepeatScheduleSheet)
//   • [6] Cảnh báo Scheduler nửa đêm
//   • [7] Nút XÓA (chỉ khi sửa, ở cuối form)
//
// Flow:
//   1. Nếu existing != null → pre-fill tất cả field từ existing
//   2. User điền form → validate → build request → gọi provider
//   3. Thành công → Navigator.pop(context, true)
//   4. Thất bại → SnackBar đỏ
//
// Lỗi từ server:
//   • "Số tiền phải lớn hơn 0" (400)
//   • "Không tìm thấy ví" (400)
//   • "Không tìm thấy danh mục" (400)
//   • "Khoản nợ không tồn tại hoặc không có quyền." (400 — debtId sai)
//   • "Khoản nợ đã thanh toán xong, không thể kích hoạt lại" (400 — toggle)
// ===========================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/debt/providers/debt_provider.dart';
import 'package:smart_money/modules/planned/enums/plan_type.dart';
import 'package:smart_money/modules/planned/enums/repeat_type.dart';
import 'package:smart_money/modules/planned/models/planned_transaction_request.dart';
import 'package:smart_money/modules/planned/models/planned_transaction_response.dart';
import 'package:smart_money/modules/planned/providers/recurring_provider.dart';
import 'package:smart_money/modules/planned/providers/bill_provider.dart';
import 'package:smart_money/modules/planned/widgets/repeat_schedule_sheet.dart';
import 'package:smart_money/modules/wallet/models/wallet_response.dart';
import 'package:smart_money/modules/transaction/services/util_service.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/modules/category/screens/category_list_screen.dart';

class PlannedFormScreen extends StatefulWidget {
  final PlanType planType;                        // Recurring hay Bill
  final PlannedTransactionResponse? existing;     // null = tạo mới, có = sửa

  const PlannedFormScreen({
    super.key,
    required this.planType,
    this.existing,
  });

  @override
  State<PlannedFormScreen> createState() => _PlannedFormScreenState();
}

class _PlannedFormScreenState extends State<PlannedFormScreen> {

  // =============================================
  // [6.1] STATE — Khai báo biến
  // =============================================

  bool get _isEditing => widget.existing != null; // true = đang sửa

  // Form fields
  int? _walletId;                     // ví đã chọn
  String? _walletName;                // tên ví hiển thị
  String? _walletIcon;                // icon URL ví (goalImageUrl)
  double? _walletBalance;             // số dư ví đã chọn
  double _amount = 0;                 // số tiền
  int? _categoryId;                   // danh mục đã chọn
  String? _categoryName;              // tên danh mục hiển thị
  String? _categoryIcon;              // icon danh mục
  bool? _categoryType;                // false=chi, true=thu
  int? _debtId;                       // ID nợ (nullable, chỉ dùng khi category là Nợ)
  String? _debtPersonName;            // tên người vay/cho vay hiển thị trong row chọn nợ
  final _noteController = TextEditingController();    // controller ghi chú
  final _amountController = TextEditingController();  // controller số tiền

  // Repeat schedule (từ RepeatScheduleSheet)
  int? _repeatType;                   // 1=daily, 2=weekly, 3=monthly, 4=yearly
  int _repeatInterval = 1;            // mỗi N đơn vị
  DateTime _beginDate = DateTime.now();
  int? _repeatOnDayVal;               // bitmask ngày tuần (weekly)
  String _endDateOption = 'FOREVER';  // "FOREVER" | "UNTIL_DATE" | "COUNT"
  DateTime? _endDateValue;            // ngày kết thúc (UNTIL_DATE)
  int? _repeatCount;                  // số lần lặp (COUNT)
  String? _repeatDescriptionPreview;  // preview text hiển thị trong form

  bool _isSaving = false;             // đang gửi request — disable nút Lưu
  bool _isDeleting = false;           // đang xóa — disable nút Xóa

  // Danh sách ví (load trực tiếp từ UtilService, không phụ thuộc WalletProvider)
  List<WalletResponse> _wallets = [];
  bool _isLoadingWallets = false;

  // ── DEBT CATEGORY IDS ──
  // 19: Cho vay, 20: Đi vay, 21: Thu nợ, 22: Trả nợ
  static const _debtCategoryIds = {19, 20, 21, 22};

  /// true khi category hiện tại yêu cầu chọn khoản nợ liên kết
  bool get _requiresDebtSelection => _debtCategoryIds.contains(_categoryId);

  /// debtType truyền vào DebtPicker:
  ///   Cho vay (19) / Thu nợ (21) → CẦN THU (debtType=true)
  ///   Đi vay (20) / Trả nợ (22) → CẦN TRẢ (debtType=false)
  bool get _debtTypeForPicker => _categoryId == 19 || _categoryId == 21;

  // =============================================
  // [6.2] initState — Pre-fill nếu đang sửa + load wallets
  // =============================================
  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final e = widget.existing!;
      _walletId = e.walletId;
      _walletName = e.walletName;
      _walletIcon = e.walletIcon; // icon URL ví từ Backend computed field
      _amount = e.amount;
      _amountController.text = FormatHelper.formatNumber(e.amount);
      _categoryId = e.categoryId;
      _categoryName = e.categoryName;
      _categoryIcon = e.categoryIcon;
      _categoryType = e.categoryType;
      _debtId = e.debtId;
      _debtPersonName = e.debtPersonName;  // pre-fill tên người nợ khi sửa
      _noteController.text = e.note ?? '';
      _repeatType = e.repeatType;
      _repeatInterval = e.repeatInterval ?? 1;
      _beginDate = e.beginDate ?? DateTime.now();
      _repeatOnDayVal = e.repeatOnDayVal;
      _repeatDescriptionPreview = e.repeatDescription;

      // [NOTE] endDateOption không có trong response → suy luận
      // Nếu endDate != null → UNTIL_DATE, còn lại → FOREVER
      if (e.endDate != null) {
        _endDateOption = 'UNTIL_DATE';
        _endDateValue = e.endDate;
      } else {
        _endDateOption = 'FOREVER';
      }
    }

    // Load wallets từ UtilService (tự auth, không cần token)
    _loadWallets();
  }

  /// Load danh sách ví cơ bản từ API (planned không dùng SavingGoal)
  Future<void> _loadWallets() async {
    _isLoadingWallets = true;
    if (mounted) setState(() {});

    try {
      final response = await UtilService.getAllWallets();
      if (response.success && response.data != null) {
        _wallets = response.data!;
      }
    } catch (e) {
      debugPrint('❌ [PlannedFormScreen] Wallet loading error: $e');
    }

    _isLoadingWallets = false;
    if (mounted) setState(() {});
  }

  // =============================================
  // [6.3] dispose
  // =============================================
  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // =============================================
  // [6.4] BUILD
  // =============================================
  @override
  Widget build(BuildContext context) {
    // Tiêu đề phụ thuộc planType + isEditing
    String title;
    if (widget.planType == PlanType.recurring) {
      title = _isEditing ? 'Modify recurring transactions' : 'New recurring transaction';
    } else {
      title = _isEditing ? 'Edit bill' : 'New bill';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Nút LƯU
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4CAF50)),
                  )
                : const Text(
                    'LƯU',
                    style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w600, fontSize: 16),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // [1] Chọn ví
            _buildWalletRow(),
            _buildDivider(),

            // [2] Nhập số tiền
            _buildAmountRow(),
            _buildDivider(),

            // [3] Chọn danh mục
            _buildCategoryRow(),
            _buildDivider(),

            // [3.5] Chọn khoản nợ (chỉ hiện khi category thuộc nhóm Nợ 19/20/21/22)
            if (_requiresDebtSelection) ...[
              _buildDebtRow(),
              _buildDivider(),
            ],

            // [4] Ghi chú
            _buildNoteRow(),
            _buildDivider(),

            // [5] Lịch lặp lại
            _buildRepeatRow(),
            _buildDivider(),

            // [6] Cảnh báo scheduler
            _buildSchedulerWarning(),

            // [7] Nút XÓA (chỉ khi sửa)
            if (_isEditing) ...[
              const SizedBox(height: 24),
              _buildDeleteButton(),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // =============================================
  // [6.5] ROW CHỌN VÍ — Hiện icon ví + tên + số dư
  // =============================================
  Widget _buildWalletRow() {
    // [1b] Dùng HitTestBehavior.opaque để đảm bảo toàn bộ khung đều nhận tap
    //      (không chỉ riêng icon ">")
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isLoadingWallets ? null : () => _showWalletPicker(_wallets),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Icon ví đã chọn (hoặc placeholder)
            _walletId != null
                ? _buildWalletIcon(_walletIcon)
                : const Icon(Icons.account_balance_wallet, color: Color(0xFF8E8E93), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _walletName ?? 'Choose a wallet',
                    style: TextStyle(
                      fontSize: 15,
                      color: _walletName != null ? Colors.white : const Color(0xFF8E8E93),
                    ),
                  ),
                  // Hiện balance nếu đã chọn ví
                  if (_walletBalance != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      FormatHelper.formatVND(_walletBalance!),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF8E8E93), size: 20),
          ],
        ),
      ),
    );
  }

  // =============================================
  // [6.6] ROW NHẬP SỐ TIỀN
  // =============================================
  Widget _buildAmountRow() {
    final isIncome = _categoryType == true;
    final amountColor = _categoryType != null
        ? (isIncome ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B))
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          // Badge "đ"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3C),
              borderRadius: BorderRadius.circular(4),
            ),
            // [TODO i18n] Currency badge
            child: const Text('đ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 14),
          // TextField số tiền
          Expanded(
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: amountColor),
              decoration: const InputDecoration(
                hintText: '0 đ',
                hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 24, fontWeight: FontWeight.bold),
                border: InputBorder.none,
              ),
              onChanged: (val) {
                // Parse số từ text (bỏ dấu chấm format)
                final cleanVal = val.replaceAll('.', '').replaceAll(',', '').trim();
                final parsed = double.tryParse(cleanVal) ?? 0;
                _amount = parsed;
                // Format lại realtime
                if (parsed > 0) {
                  final formatted = FormatHelper.formatNumber(parsed);
                  if (formatted != val) {
                    _amountController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [6.7] ROW CHỌN DANH MỤC
  // =============================================
  Widget _buildCategoryRow() {
    return GestureDetector(
      onTap: _openCategoryPicker,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Icon category (nếu đã chọn) hoặc icon mặc định
            if (_categoryIcon != null)
              IconHelper.buildCircleAvatar(iconUrl: _categoryIcon, radius: 16)
            else
              const Icon(Icons.category, color: Color(0xFF8E8E93), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _categoryName ?? 'Select category',
                style: TextStyle(
                  fontSize: 15,
                  color: _categoryName != null ? Colors.white : const Color(0xFF8E8E93),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF8E8E93), size: 20),
          ],
        ),
      ),
    );
  }

  // =============================================
  // [6.8] ROW GHI CHÚ
  // =============================================
  Widget _buildNoteRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.edit_note, color: Color(0xFF8E8E93), size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Note (optional)',
                hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [6.9] ROW LỊCH LẶP LẠI
  // =============================================
  Widget _buildRepeatRow() {
    return GestureDetector(
      onTap: _openRepeatScheduleSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.repeat, color: Color(0xFF8E8E93), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _repeatDescriptionPreview ?? 'Please select a recurring schedule.',
                style: TextStyle(
                  fontSize: 15,
                  color: _repeatType != null ? Colors.white : const Color(0xFF8E8E93),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF8E8E93), size: 20),
          ],
        ),
      ),
    );
  }

  // =============================================
  // [6.10] CẢNH BÁO SCHEDULER
  // =============================================
  Widget _buildSchedulerWarning() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3B30), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Note: Recurring transactions will not be executed immediately.'
              'The system will process automatically at midnight.',
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [6.11] NÚT XÓA (chỉ khi sửa)
  // =============================================
  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: _isDeleting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF3B30)))
            : const Icon(Icons.delete_outline, color: Color(0xFFFF3B30)),
        label: const Text('Delete', style: TextStyle(color: Color(0xFFFF3B30), fontSize: 15)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFFF3B30)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: _isDeleting ? null : _confirmDelete,
      ),
    );
  }

  // =============================================
  // [6.12] DIVIDER
  // =============================================
  Widget _buildDivider() {
    return const Divider(height: 1, color: Color(0xFF3A3A3C));
  }

  // =============================================
  // [6.13] MỞ WALLET PICKER — BottomSheet chọn ví với icon + balance
  // =============================================
  // [NOTE] Planned KHÔNG dùng SavingGoal, chỉ dùng Wallet cơ bản
  // WalletProvider.wallets đã chỉ trả wallet (SavingGoal là entity riêng)
  void _showWalletPicker(List<WalletResponse> wallets) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose a wallet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1, color: Color(0xFF3A3A3C)),
            // Danh sách ví
            ...wallets.map((w) {
              final selected = _walletId == w.id;
              return ListTile(
                // ✅ Icon ví từ goalImageUrl
                leading: _buildWalletIcon(w.goalImageUrl),
                // ✅ Tên ví
                title: Text(
                  w.walletName,
                  style: TextStyle(
                    color: selected ? const Color(0xFF4CAF50) : Colors.white,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                // ✅ Balance
                subtitle: Text(
                  FormatHelper.formatVND(w.balance),
                  style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                ),
                trailing: selected
                    ? const Icon(Icons.check, color: Color(0xFF4CAF50))
                    : null,
                onTap: () {
                  setState(() {
                    _walletId = w.id;
                    _walletName = w.walletName;
                    _walletIcon = w.goalImageUrl;
                    _walletBalance = w.balance;
                  });
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // =============================================
  // [6.13b] HELPER — Build icon ví (CachedNetworkImage + fallback)
  // =============================================
  Widget _buildWalletIcon(String? iconUrl) {
    final cloudinaryUrl = IconHelper.buildCloudinaryUrl(iconUrl);

    if (cloudinaryUrl != null && cloudinaryUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cloudinaryUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        imageBuilder: (context, imageProvider) {
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          );
        },
        placeholder: (_, __) => _buildDefaultWalletIcon(),
        errorWidget: (_, __, ___) => _buildDefaultWalletIcon(),
      );
    }

    return _buildDefaultWalletIcon();
  }

  // Fallback icon khi không có URL
  Widget _buildDefaultWalletIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.green.shade400,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
    );
  }

  // =============================================
  // [6.15] MỞ REPEAT SCHEDULE SHEET
  // =============================================
  void _openRepeatScheduleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return RepeatScheduleSheet(
          initialRepeatType: _repeatType,
          initialInterval: _repeatInterval,
          initialBeginDate: _beginDate,
          initialDayBitmask: _repeatOnDayVal,
          initialEndDateOption: _endDateOption,
          initialEndDateValue: _endDateValue,
          initialRepeatCount: _repeatCount,
          isEditing: _isEditing,
          isActive: widget.existing?.active ?? true,
          onToggle: () {
            // Toggle active — gọi provider
            if (_isEditing) {
              final id = widget.existing!.id;
              if (widget.planType == PlanType.recurring) {
                Provider.of<RecurringProvider>(context, listen: false).toggle(id);
              } else {
                Provider.of<BillProvider>(context, listen: false).toggle(id);
              }
            }
          },
          onConfirm: (result) {
            setState(() {
              _repeatType = result.repeatType;
              _repeatInterval = result.repeatInterval;
              _beginDate = result.beginDate;
              _repeatOnDayVal = result.repeatOnDayVal;
              _endDateOption = result.endDateOption;
              _endDateValue = result.endDateValue;
              _repeatCount = result.repeatCount;
              // Build preview description cho form
              _repeatDescriptionPreview = _buildRepeatPreview(result);
            });
          },
        );
      },
    );
  }

  // =============================================
  // [6.16] BUILD REPEAT PREVIEW — Mô tả hiển thị trong form
  // =============================================
  // Chỉ dùng khi chưa lưu (preview). Sau khi lưu, dùng repeatDescription từ Backend.
  String _buildRepeatPreview(RepeatScheduleResult result) {
    final type = RepeatType.fromValue(result.repeatType);
    final interval = result.repeatInterval;

    switch (type) {
      case RepeatType.daily:
        return interval == 1 ? 'Repeat daily' : 'Repeat each $interval day';
      case RepeatType.weekly:
        final dayNames = FormatHelper.getDayNames(result.repeatOnDayVal ?? 0);
        final daysStr = dayNames.join(', ');
        return interval == 1
            ? 'Repeat weekly ($daysStr)'
            : 'Repeat each $interval week ($daysStr)';
      case RepeatType.monthly:
        final day = result.beginDate.day;
        return interval == 1
            ? 'Repeat on the same day $day of the month.'
            : 'Repeat on the same day $day, of each $interval month';
      case RepeatType.yearly:
        return interval == 1 ? 'Repeat annually' : 'Repeat each $interval years';
      default:
        return 'No repeat';
    }
  }

  // =============================================
  // [6.14] MỞ CATEGORY PICKER
  // =============================================
  Future<void> _openCategoryPicker() async {
    // Navigate sang CategoryListScreen với mode chọn (selection mode)
    // Trả về CategoryResponse khi user chọn xong
    final result = await Navigator.push<CategoryResponse>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryListScreen(
          isSelectMode: true,
          // Với Bill: chỉ hiện expense + debt
          // Với Recurring: hiện cả 3 tab
          initialTab: 'expense',
        ),
      ),
    );

    // [IMPORTANT] Kiểm tra mounted sau await
    if (!mounted || result == null) return;

    setState(() {
      _categoryId = result.id;
      _categoryName = result.ctgName;
      _categoryIcon = result.ctgIconUrl;
      _categoryType = result.ctgType;

      // [FIX] Reset debt khi đổi sang category không thuộc nhóm Nợ (19/20/21/22)
      // Tránh gửi debtId cũ lên server khi category mới không liên quan đến nợ
      if (!_debtCategoryIds.contains(result.id)) {
        _debtId = null;
        _debtPersonName = null;
      }
    });
  }

  // =============================================
  // [6.14b] MỞ DEBT PICKER — BottomSheet chọn khoản nợ
  // =============================================
  // Gọi khi: User tap vào row "Chọn khoản nợ" (_buildDebtRow)
  // Tham số ngầm: _debtTypeForPicker — true=CẦN THU, false=CẦN TRẢ
  // [NOTE] Load debt từ DebtProvider (đã có sẵn trong context)
  Future<void> _showDebtPicker() async {
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final debtType = _debtTypeForPicker;

    // Bước 1: Load danh sách nợ theo loại (CẦN THU hoặc CẦN TRẢ)
    await debtProvider.loadDebts(debtType);
    if (!mounted) return;

    // Bước 2: Lấy danh sách chưa hoàn thành để chọn
    // finished=false → còn đang nợ → mới được liên kết với planned
    final debts = debtType
        ? debtProvider.receivableDebts   // CẦN THU — Cho vay chưa thu
        : debtProvider.payableDebts;     // CẦN TRẢ — Đi vay chưa trả

    final tabLabel = debtType ? 'NEED TO COLLECT' : 'PAYMENT REQUIRED';
    final activeColor = debtType ? Colors.blue : Colors.orange;

    // Bước 3: Hiện bottom sheet chọn khoản nợ
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row: icon loại + tiêu đề + nút "Bỏ chọn"
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Icon(
                      debtType ? Icons.arrow_downward : Icons.arrow_upward,
                      color: activeColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Select account $tabLabel',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Nút Bỏ chọn — chỉ hiện khi đã chọn debt
                    if (_debtId != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _debtId = null;
                            _debtPersonName = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Deselect',
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey, height: 1),

              // Bước 4: Danh sách khoản nợ hoặc thông báo rỗng
              if (debts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No amount $tabLabel is incomplete.',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: debts.length,
                    itemBuilder: (_, i) {
                      final debt = debts[i];
                      final isSelected = _debtId == debt.id;
                      return ListTile(
                        // Avatar người nợ — đổi màu khi selected
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? activeColor : Colors.grey[800],
                          child: const Icon(Icons.person, color: Colors.white, size: 18),
                        ),
                        // Tên người vay/cho vay
                        title: Text(
                          debt.personName,
                          style: TextStyle(
                            color: isSelected ? activeColor : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        // Số tiền còn lại
                        subtitle: Text(
                          'Remaining: ${FormatHelper.formatVND(debt.remainAmount)}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        // Icon check khi đang selected
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: activeColor)
                            : null,
                        onTap: () {
                          // Bước 5: Gán debtId + debtPersonName, đóng sheet
                          setState(() {
                            _debtId = debt.id;
                            _debtPersonName = debt.personName;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // =============================================
  // [6.14c] ROW CHỌN KHOẢN NỢ — chỉ hiện khi _requiresDebtSelection = true
  // =============================================
  Widget _buildDebtRow() {
    final debtType = _debtTypeForPicker;
    final activeColor = debtType ? Colors.blue : Colors.orange;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showDebtPicker,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Icon loại nợ — đổi màu khi đã chọn
            Icon(
              Icons.account_balance,
              color: _debtId != null ? activeColor : const Color(0xFF8E8E93),
              size: 24,
            ),
            const SizedBox(width: 14),
            // Tên người nợ hoặc placeholder
            Expanded(
              child: Text(
                _debtPersonName ?? 'Select linked debt',
                style: TextStyle(
                  fontSize: 15,
                  color: _debtPersonName != null ? Colors.white : const Color(0xFF8E8E93),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF8E8E93), size: 20),
          ],
        ),
      ),
    );
  }

  // =============================================
  // [6.17] SAVE — Validate + Build request + Gọi Provider
  // =============================================
  Future<void> _save() async {
    // Bước 1: Validate
    if (_walletId == null) {
      _showSnackBar('Please select a wallet.');
      return;
    }
    if (_amount <= 0) {
      _showSnackBar('The amount must be greater than 0.');
      return;
    }
    if (_categoryId == null) {
      _showSnackBar('Please select a category');
      return;
    }
    // [FIX] Validate debt khi category thuộc nhóm Nợ (19/20/21/22)
    // Nếu không chọn debt → debtId=null → backend tạo Transaction không liên kết nợ
    // → sổ nợ không recalculate → số dư sổ nợ sai
    if (_requiresDebtSelection && _debtId == null) {
      _showSnackBar('Please select the linked debt.');
      return;
    }
    if (_repeatType == null) {
      _showSnackBar('You need to select a recurring schedule.');
      return;
    }
    // Lặp tuần mà chưa chọn thứ nào
    if (_repeatType == RepeatType.weekly.value && (_repeatOnDayVal == null || _repeatOnDayVal == 0)) {
      _showSnackBar('Please select at least one day of the week.');
      return;
    }
    // COUNT mà repeatCount < 1
    if (_endDateOption == 'COUNT' && (_repeatCount == null || _repeatCount! < 1)) {
      _showSnackBar('The number of repetitions must be >= 1');
      return;
    }

    // Bước 2: Build request
    final request = PlannedTransactionRequest(
      walletId: _walletId!,
      amount: _amount,
      categoryId: _categoryId!,
      debtId: _debtId,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      planType: widget.planType.value,
      repeatType: _repeatType!,
      repeatInterval: _repeatInterval,
      repeatOnDayVal: _repeatOnDayVal,
      beginDate: _beginDate,
      endDateOption: _endDateOption,
      endDateValue: _endDateValue,
      repeatCount: _repeatCount,
    );

    // Bước 3: Gọi Provider
    setState(() => _isSaving = true);

    bool success;
    if (widget.planType == PlanType.recurring) {
      final provider = Provider.of<RecurringProvider>(context, listen: false);
      if (_isEditing) {
        success = await provider.update(widget.existing!.id, request);
      } else {
        success = await provider.create(request);
      }
    } else {
      final provider = Provider.of<BillProvider>(context, listen: false);
      if (_isEditing) {
        success = await provider.update(widget.existing!.id, request);
      } else {
        success = await provider.create(request);
      }
    }

    // Bước 4: Tắt loading
    setState(() => _isSaving = false);

    // [IMPORTANT] Kiểm tra mounted sau await
    if (!mounted) return;

    // Bước 5: Hiện kết quả
    if (success) {
      Navigator.pop(context, true); // trả result=true để màn cha biết
    } else {
      // Lấy errorMessage từ provider
      String? err;
      if (widget.planType == PlanType.recurring) {
        err = Provider.of<RecurringProvider>(context, listen: false).errorMessage;
      } else {
        err = Provider.of<BillProvider>(context, listen: false).errorMessage;
      }
      _showSnackBar(err ?? 'An error occurred.', isError: true);
    }
  }

  // =============================================
  // [6.18] CONFIRM DELETE — Dialog xác nhận xóa
  // =============================================
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: Text(
          widget.planType == PlanType.recurring ? 'Delete recurring transactions?' : 'Delete the bill?',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          'This action cannot be restore.',
          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // đóng dialog
              setState(() => _isDeleting = true);

              bool success;
              final id = widget.existing!.id;
              if (widget.planType == PlanType.recurring) {
                success = await Provider.of<RecurringProvider>(context, listen: false).delete(id);
              } else {
                success = await Provider.of<BillProvider>(context, listen: false).delete(id);
              }

              setState(() => _isDeleting = false);
              if (!mounted) return;

              if (success) {
                Navigator.pop(context, true);
              } else {
                _showSnackBar('Cannot delete. Please try again.', isError: true);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [6.19] HELPER — Hiện SnackBar
  // =============================================
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFFF3B30) : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}


