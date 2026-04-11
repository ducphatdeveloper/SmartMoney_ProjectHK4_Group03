// ===========================================================
// [6] TransactionEditScreen — Màn hình sửa giao dịch
// ===========================================================
// Giống TransactionCreateScreen nhưng:
//   • Pre-fill toàn bộ field từ TransactionResponse truyền vào
//   • AppBar tiêu đề: "Sửa giao dịch"
//   • Thêm nút Xóa (OutlinedButton đỏ, bên dưới nút Lưu)
//   • Nút Lưu → gọi provider.updateTransaction(id, request)
//   • Nút Xóa → showDialog xác nhận → gọi provider.deleteTransaction(id)
//   • Cả 2 thành công → Navigator.pop(context, true) — màn cha reload
//
// Flow:
//   1. initState → pre-fill tất cả field từ TransactionResponse
//   2. User sửa → thay đổi state
//   3. User bấm Lưu → validate → gọi provider.updateTransaction()
//   4. User bấm Xóa → confirm dialog → gọi provider.deleteTransaction()
//   5. Thành công → Navigator.pop(context, true)
//   6. Thất bại → hiện SnackBar đỏ + message lỗi từ server
//
// Lỗi từ server:
//   • "Bạn không có quyền sửa giao dịch này." (403)
//   • "Bạn không có quyền xóa giao dịch này." (403)
//   • "Số tiền phải lớn hơn 0" (400)
//   • "Không tìm thấy ví" (400)
//   • "Không tìm thấy danh mục" (400)
// ===========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/transaction/models/request/transaction_request.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';
import 'package:smart_money/modules/transaction/models/source_item.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_type_selector.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_date_picker.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_amount_field.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_category_row.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/modules/category/screens/category_list_screen.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/event/providers/event_provider.dart';
import 'package:smart_money/modules/event/models/event_response.dart';
import 'package:smart_money/modules/debt/providers/debt_provider.dart';
import 'package:smart_money/modules/debt/models/debt_response.dart';

class TransactionEditScreen extends StatefulWidget {
  final TransactionResponse transaction; // giao dịch cần sửa

  const TransactionEditScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<TransactionEditScreen> createState() => _TransactionEditScreenState();
}

class _TransactionEditScreenState extends State<TransactionEditScreen> {

  // =============================================
  // [6.1] STATE — Khai báo biến state
  // =============================================

  String _transactionType = 'expense';          // loại giao dịch: 'expense' | 'income' | 'debt'
  SourceItem? _selectedSourceItem;              // ví đã chọn (wallet hoặc saving goal)
  CategoryResponse? _selectedCategory;          // nhóm danh mục đã chọn
  String _amountStr = '0';                      // số tiền dạng string từ bàn phím
  final _noteController = TextEditingController(); // controller ô ghi chú
  DateTime _transDate = DateTime.now();          // ngày giao dịch
  bool _showDetails = false;                     // hiện/ẩn phần chi tiết bổ sung
  final _withPersonController = TextEditingController(); // controller "Với ai"
  int? _selectedEventId;                         // ID sự kiện đã chọn (nullable) — gửi lên server
  String? _selectedEventDisplay;                // tên sự kiện đã chọn — hiển thị trên UI
  int? _selectedDebtId;                          // ID khoản nợ đã chọn (nullable) — gửi lên server
  String? _selectedDebtDisplay;                 // tên/info khoản nợ đã chọn — hiển thị trên UI
  DateTime? _reminderTime;                       // nhắc nhở (nullable, phải > now)
  bool _notReportable = false;                   // checkbox "Không tính vào báo cáo"
  bool _isSaving = false;                        // đang gửi request — disable nút Lưu/Xóa
  bool _isLoadingSources = false;                // đang load ví/mục tiêu — hiện loading trong wallet row
  String _pendingOperator = '';                   // toán tử đang chờ (+, -, ×, ÷)
  double _previousValue = 0;                     // giá trị trước toán tử
  bool _waitingForNextNumber = false;             // [FIX-4] true = vừa bấm toán tử, chờ user nhập số mới
  bool _isAmountFocused = false;                 // [FIX-3] true khi user tap vào ô số tiền → hiện calculator

  // FocusNodes để theo dõi focus text field → ẩn/hiện calculator keyboard
  final _noteFocusNode = FocusNode();
  final _withPersonFocusNode = FocusNode();
  bool _isTextFieldFocused = false;              // true khi đang focus text field → ẩn calculator

  // =============================================
  // [6.2] initState — pre-fill dữ liệu từ TransactionResponse
  // =============================================
  @override
  void initState() {
    super.initState();

    // Đăng ký focus listeners cho text fields
    _noteFocusNode.addListener(_onFocusChanged);
    _withPersonFocusNode.addListener(_onFocusChanged);

    // Pre-fill tất cả field từ transaction truyền vào
    final tx = widget.transaction;

    // Xác định loại giao dịch từ categoryType
    // categoryType: true = Thu (income), false = Chi (expense)
    // Nếu có debtId → debt
    if (tx.debtId != null) {
      _transactionType = 'debt';
    } else if (tx.categoryType) {
      _transactionType = 'income';
    } else {
      _transactionType = 'expense';
    }

    // Pre-fill nguồn tiền (wallet hoặc saving goal)
    if (tx.savingGoalId != null) {
      _selectedSourceItem = SourceItem.fromSavingGoal(
        id: tx.savingGoalId!,
        name: tx.savingGoalName ?? 'Mục tiêu',
        iconUrl: tx.savingGoalIconUrl,
      );
    } else if (tx.walletId != null) {
      _selectedSourceItem = SourceItem.fromWallet(
        id: tx.walletId!,
        name: tx.walletName ?? 'Ví',
        iconUrl: tx.walletIconUrl,
      );
    }

    // Pre-fill danh mục
    if (tx.categoryId != null) {
      _selectedCategory = CategoryResponse(
        id: tx.categoryId!,
        ctgName: tx.categoryName ?? '',
        ctgType: tx.categoryType,
        ctgIconUrl: tx.categoryIconUrl,
      );
    }

    // Pre-fill số tiền
    _amountStr = tx.amount.toInt().toString();

    // Pre-fill ghi chú
    _noteController.text = tx.note ?? '';

    // Pre-fill ngày giao dịch
    _transDate = tx.transDate;

    // Pre-fill "Với ai"
    _withPersonController.text = tx.withPerson ?? '';

    // Pre-fill sự kiện
    _selectedEventId = tx.eventId;
    // eventName có sẵn trong TransactionResponse — dùng ngay làm display text
    _selectedEventDisplay = tx.eventName;

    // Pre-fill khoản nợ liên kết
    _selectedDebtId = tx.debtId;
    // TransactionResponse chỉ có debtId, không có tên → hiển thị placeholder
    // User có thể mở picker để xem và đổi khoản nợ nếu muốn
    _selectedDebtDisplay = tx.debtId != null ? 'Khoản nợ đã liên kết' : null;

    // Pre-fill "Không tính vào báo cáo"
    _notReportable = !tx.reportable;

    // Nếu có chi tiết bổ sung → mở sẵn
    if (tx.withPerson != null || tx.eventId != null || !tx.reportable) {
      _showDetails = true;
    }

    // [FIX-SOURCES] Đảm bảo sourceItems (ví + mục tiêu) đã được load.
    // Trường hợp mở từ màn hình khác không qua TransactionListScreen
    // → provider.sourceItems có thể rỗng → picker ví hiện trống.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<TransactionProvider>();
      if (provider.sourceItems.isEmpty) {
        setState(() => _isLoadingSources = true);
        await provider.ensureSourceItemsLoaded();
        if (mounted) setState(() => _isLoadingSources = false);
      }
    });
  }

  void _onFocusChanged() {
    final focused = _noteFocusNode.hasFocus || _withPersonFocusNode.hasFocus;
    if (focused != _isTextFieldFocused) {
      setState(() {
        _isTextFieldFocused = focused;
        // [FIX-3] Khi text field được focus → ẩn bàn phím tính toán
        if (focused) _isAmountFocused = false;
      });
    }
  }

  // =============================================
  // [6.3] dispose — giải phóng tài nguyên
  // =============================================
  @override
  void dispose() {
    _noteFocusNode.removeListener(_onFocusChanged);
    _withPersonFocusNode.removeListener(_onFocusChanged);
    _noteFocusNode.dispose();
    _withPersonFocusNode.dispose();
    _noteController.dispose();
    _withPersonController.dispose();
    super.dispose();
  }

  // =============================================
  // [6.4] _save — xử lý khi bấm nút Lưu (cập nhật)
  // =============================================
  Future<void> _save() async {
    // Bước 1: Validate client-side
    final amount = double.tryParse(_amountStr) ?? 0;
    if (amount <= 0) {
      _showSnackBar('Vui lòng nhập số tiền lớn hơn 0', isError: true);
      return;
    }
    if (_selectedCategory == null) {
      _showSnackBar('Vui lòng chọn nhóm danh mục', isError: true);
      return;
    }
    if (_selectedSourceItem == null) {
      _showSnackBar('Vui lòng chọn ví', isError: true);
      return;
    }

    // Bước 2: Validate nhắc nhở nếu có
    if (_reminderTime != null && _reminderTime!.isBefore(DateTime.now())) {
      _showSnackBar('Nhắc nhở phải là thời gian tương lai', isError: true);
      return;
    }

    // Bước 2.5: Confirm trước khi lưu — tránh bấm nhầm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Xác nhận sửa', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc muốn cập nhật giao dịch này?',
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

    // Bước 3: Build request body
    final request = TransactionRequest(
      walletId: _selectedSourceItem!.type == 'wallet' ? _selectedSourceItem!.id : null,
      goalId: _selectedSourceItem!.type == 'saving_goal' ? _selectedSourceItem!.id : null,
      amount: amount,
      categoryId: _selectedCategory!.id,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      transDate: _transDate,
      withPerson: _withPersonController.text.trim().isNotEmpty
          ? _withPersonController.text.trim()
          : null,
      eventId: _selectedEventId,
      debtId: _selectedDebtId, // liên kết khoản nợ — chỉ khi category Thu nợ (21) hoặc Trả nợ (22)
      reminderDate: _reminderTime,
      reportable: !_notReportable,
    );

    // Bước 4: Gọi Provider
    setState(() => _isSaving = true);
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final success = await provider.updateTransaction(widget.transaction.id, request);
    setState(() => _isSaving = false);

    // Bước 5: Kiểm tra mounted sau await
    if (!mounted) return;

    // Bước 6: Hiện kết quả
    if (success) {
      _showSnackBar(provider.successMessage ?? 'Cập nhật giao dịch thành công');
      Navigator.pop(context, true);
    } else {
      _showSnackBar(provider.errorMessage ?? 'Có lỗi xảy ra', isError: true);
    }
  }

  // =============================================
  // [6.5] _confirmDelete — xác nhận xóa giao dịch
  // =============================================
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Xóa giao dịch',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Bạn có chắc muốn xóa giao dịch này? Thao tác không thể hoàn tác.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), // đóng dialog
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // đóng dialog trước
              _delete(); // thực hiện xóa
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [6.5b] _delete — thực hiện xóa giao dịch
  // =============================================
  Future<void> _delete() async {
    setState(() => _isSaving = true);
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final success = await provider.deleteTransaction(widget.transaction.id);
    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      _showSnackBar(provider.successMessage ?? 'Đã xóa giao dịch');
      Navigator.pop(context, true);
    } else {
      _showSnackBar(provider.errorMessage ?? 'Có lỗi xảy ra', isError: true);
    }
  }

  // =============================================
  // [6.6] _navigateToSelectCategory — mở màn chọn nhóm
  // =============================================
  void _navigateToSelectCategory() async {
    final result = await Navigator.push<CategoryResponse>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryListScreen(
          isSelectMode: true,
          initialTab: _transactionType,
        ),
      ),
    );

    if (result != null && mounted) {
      final inferredType = _inferTabFromCategory(result);
      setState(() {
        _selectedCategory = result;
        // [FIX-1] Auto-switch tab để đồng bộ với category đã chọn
        _transactionType = inferredType;
        // [FIX] Nếu đổi sang category không phải Thu nợ (21) hoặc Trả nợ (22)
        // → xóa khoản nợ đã liên kết vì không còn phù hợp
        if (result.id != 21 && result.id != 22) {
          _selectedDebtId = null;
          _selectedDebtDisplay = null;
        }
      });
    }
  }

  // =============================================
  // [6.6c] _inferTabFromCategory — xác định tab từ category đã chọn
  // =============================================
  String _inferTabFromCategory(CategoryResponse category) {
    const debtIds = {19, 20, 21, 22};
    if (debtIds.contains(category.id)) return 'debt';
    return (category.ctgType == true) ? 'income' : 'expense';
  }

  // =============================================
  // [6.6b] _showSourceBottomSheet — mở bottom sheet chọn ví
  // =============================================
  void _showSourceBottomSheet() {
    // Guard: đang tải thì không mở
    if (_isLoadingSources) return;

    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final sources = provider.sourceItems;

    // Lọc bỏ item "Tổng cộng" — khi sửa giao dịch phải chọn ví cụ thể
    final selectableSources = sources.where((s) => s.type != 'all').toList();

    // Nếu chưa có ví nào → hiện thông báo
    if (selectableSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy ví nào. Vui lòng tạo ví trước.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: selectableSources.length,
          itemBuilder: (ctx, index) {
            final item = selectableSources[index];
            final isSelected = _selectedSourceItem?.id == item.id &&
                _selectedSourceItem?.type == item.type;

            return ListTile(
              leading: _buildSourceIcon(item),
              title: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.green : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: item.balance != null
                  ? Text(
                      FormatHelper.formatVND(item.balance),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    )
                  : null,
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
               onTap: () {
                 setState(() {
                   _selectedSourceItem = item;
                   // [FIX] Chỉ cập nhật ví, không reset category/event/debt — để user tự quản lý
                 });
                 Navigator.pop(ctx);
               },
            );
          },
        );
      },
    );
  }

  // =============================================
  // [6.7] Helper getters — xác định trạng thái nợ
  // =============================================

  // true khi category là Thu nợ (21) hoặc Trả nợ (22) — hiện row liên kết khoản nợ
  bool get _requiresDebtSelection =>
      _selectedCategory?.id == 21 || _selectedCategory?.id == 22;

  // debtType truyền vào picker:
  //   Thu nợ (21) → CẦN THU (debtType=true)
  //   Trả nợ (22) → CẦN TRẢ (debtType=false)
  bool get _debtTypeForPicker => _selectedCategory?.id == 21;

  // =============================================
  // [6.8] _showEventPicker — bottom sheet chọn sự kiện đang diễn ra
  // =============================================
  // Gọi khi: User bấm vào dòng "Chọn sự kiện" trong phần chi tiết
  // API: GET /api/events?isFinished=false (tái dùng EventProvider)
  Future<void> _showEventPicker() async {
    // Bước 1: Load danh sách sự kiện đang diễn ra
    // [FIX-2] forceRefresh=true để luôn lấy totals mới nhất từ server
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    await eventProvider.loadEvents(false, forceRefresh: true);

    // Bước 2: Kiểm tra mounted sau await
    if (!mounted) return;

    final events = eventProvider.events;

    // Bước 3: Hiện bottom sheet
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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.event, color: Color(0xFF4CAF50), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Chọn sự kiện đang diễn ra',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_selectedEventId != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedEventId = null;
                            _selectedEventDisplay = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Bỏ chọn', style: TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey, height: 1),

              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Không có sự kiện đang diễn ra',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: events.length,
                    itemBuilder: (_, i) {
                      final EventResponse event = events[i];
                      final isSelected = _selectedEventId == event.id;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        // Icon thật của sự kiện từ Cloudinary (cùng nguồn wallet/category)
                        leading: IconHelper.buildCircleAvatar(
                          iconUrl: event.eventIconUrl,
                          radius: 22,
                          backgroundColor: isSelected
                              ? const Color(0xFF4CAF50)
                              : Colors.grey.shade800,
                          placeholder: Icon(Icons.event, color: Colors.grey, size: 22),
                        ),
                        title: Text(
                          event.eventName,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF4CAF50) : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        // Hiện ngày kết thúc + thu/chi/còn lại của sự kiện
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đến ${FormatHelper.formatDate(event.endDate)}',
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Thu: ${FormatHelper.formatShort(event.totalIncome)}',
                                  style: const TextStyle(color: Colors.green, fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Chi: ${FormatHelper.formatShort(event.totalExpense)}',
                                  style: const TextStyle(color: Colors.red, fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Còn: ${FormatHelper.formatShort(event.netAmount)}',
                                  style: TextStyle(
                                    color: event.netAmount >= 0 ? Colors.blue : Colors.orange,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50))
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedEventId = event.id;
                            _selectedEventDisplay = event.eventName;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // =============================================
  // [6.9] _showDebtPicker — bottom sheet chọn khoản nợ
  // =============================================
  // Gọi khi: User bấm vào dòng "Chọn khoản nợ" (chỉ khi category là Thu nợ/Trả nợ)
  // API: GET /api/debts?debtType=false|true (tái dùng DebtProvider)
  Future<void> _showDebtPicker() async {
    // Bước 1: Load khoản nợ phù hợp
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final debtType = _debtTypeForPicker;
    await debtProvider.loadDebts(debtType);

    // Bước 2: Kiểm tra mounted sau await
    if (!mounted) return;

    // Bước 3: Lấy danh sách chưa hoàn thành
    final debts = debtType
        ? debtProvider.receivableDebts
        : debtProvider.payableDebts;

    final tabLabel = debtType ? 'CẦN THU' : 'CẦN TRẢ';

    // Bước 4: Hiện bottom sheet
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Icon(
                      debtType ? Icons.arrow_downward : Icons.arrow_upward,
                      color: debtType ? Colors.blue : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Chọn khoản $tabLabel',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_selectedDebtId != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDebtId = null;
                            _selectedDebtDisplay = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Bỏ chọn', style: TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey, height: 1),

              if (debts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Không có khoản $tabLabel nào chưa hoàn thành',
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
                      final DebtResponse debt = debts[i];
                      final isSelected = _selectedDebtId == debt.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? (debtType ? Colors.blue : Colors.orange)
                              : Colors.grey[800],
                          child: const Icon(Icons.person, color: Colors.white, size: 18),
                        ),
                        title: Text(
                          debt.personName,
                          style: TextStyle(
                            color: isSelected
                                ? (debtType ? Colors.blue : Colors.orange)
                                : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          'Còn lại: ${FormatHelper.formatVND(debt.remainAmount)}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: debtType ? Colors.blue : Colors.orange)
                            : null,
                        onTap: () {
                          // Chọn khoản nợ → cập nhật ID, tên hiển thị
                          // [FIX] Auto-fill withPerson từ tên người trong khoản nợ đã chọn
                          setState(() {
                            _selectedDebtId = debt.id;
                            _selectedDebtDisplay = debt.personName;
                            _withPersonController.text = debt.personName; // auto-fill
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // =============================================
  // [6.7] _onKeyPressed — xử lý bàn phím tính toán
  // =============================================
  void _onKeyPressed(String key) {
    setState(() {
      switch (key) {
        case 'C':
          _amountStr = '0';
          _pendingOperator = '';
          _previousValue = 0;
          _waitingForNextNumber = false;
          break;

        case '⌫':
          if (_waitingForNextNumber) break;
          if (_amountStr.length > 1) {
            _amountStr = _amountStr.substring(0, _amountStr.length - 1);
          } else {
            _amountStr = '0';
          }
          break;

        case '000':
          if (_waitingForNextNumber) {
            _waitingForNextNumber = false;
          } else if (_amountStr != '0') {
            _amountStr += '000';
          }
          break;

        case '.':
          if (_waitingForNextNumber) {
            _amountStr = '0.';
            _waitingForNextNumber = false;
          } else if (!_amountStr.contains('.')) {
            _amountStr += '.';
          }
          break;

        case '+':
        case '-':
        case '×':
        case '÷':
          // [FIX-4] Giữ hiển thị số hiện tại, chỉ chờ user nhập số mới
          if (_pendingOperator.isNotEmpty && !_waitingForNextNumber) {
            final current = double.tryParse(_amountStr) ?? 0;
            _previousValue = _calcResult(_previousValue, current, _pendingOperator);
            _amountStr = _formatCalcResult(_previousValue);
          } else {
            _previousValue = double.tryParse(_amountStr) ?? 0;
          }
          _pendingOperator = key;
          _waitingForNextNumber = true;
          break;

        case '>':
          if (_pendingOperator.isNotEmpty && !_waitingForNextNumber) {
            final current = double.tryParse(_amountStr) ?? 0;
            final result = _calcResult(_previousValue, current, _pendingOperator);
            _amountStr = _formatCalcResult(result);
            _pendingOperator = '';
            _previousValue = 0;
            _waitingForNextNumber = false;
          }
          // [FIX-3] Ẩn bàn phím sau khi bấm ✓
          _isAmountFocused = false;
          break;

        default:
          if (_waitingForNextNumber) {
            _amountStr = key;
            _waitingForNextNumber = false;
          } else if (_amountStr == '0') {
            _amountStr = key;
          } else {
            _amountStr += key;
          }
          break;
      }
    });
  }

  double _calcResult(double a, double b, String op) {
    switch (op) {
      case '+': return a + b;
      case '-': return a - b;
      case '×': return a * b;
      case '÷': return b != 0 ? a / b : 0;
      default:  return b;
    }
  }

  String _formatCalcResult(double value) {
    if (value == value.toInt().toDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  // =============================================
  // [6.7b] _showSnackBar — hiện thông báo
  // =============================================
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // =============================================
  // [6.8] build — giao diện chính
  // =============================================
  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountStr) ?? 0;
    final canSave = _selectedCategory != null &&
        amount > 0 &&
        _selectedSourceItem != null &&
        !_isSaving;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sửa giao dịch',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          // [FIX-3] Ẩn bàn phím khi bấm ra ngoài ô số tiền
          setState(() => _isAmountFocused = false);
        },
        child: Column(
          children: [
            // ===== Phần form (cuộn được) =====
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // [A] 3 tab selector: Khoản chi | Khoản thu | Vay/Nợ
                    TransactionTypeSelector(
                      selectedType: _transactionType,
                      showDebtTab: _selectedSourceItem?.type != 'saving_goal',
                      onChanged: (type) {
                        setState(() {
                          _transactionType = type;
                          _selectedCategory = null;
                        });
                      },
                    ),

                    const Divider(color: Colors.grey, height: 1),

                    // [B] Row chọn ví
                    _buildWalletRow(),

                    const Divider(color: Colors.grey, height: 1),

                    // [C] Row hiển thị số tiền
                    // [FIX-3] Bọc GestureDetector để bắt tap → hiện calculator keyboard
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        setState(() => _isAmountFocused = true);
                      },
                      child: TransactionAmountField(
                        amount: _amountStr,
                        transactionType: _transactionType,
                      ),
                    ),

                    const Divider(color: Colors.grey, height: 1),

                    // [D] Row chọn nhóm danh mục
                    TransactionCategoryRow(
                      selected: _selectedCategory,
                      onTap: _navigateToSelectCategory,
                    ),

                    const Divider(color: Colors.grey, height: 1),

                    // [E] Row ghi chú
                    _buildNoteRow(),

                    const Divider(color: Colors.grey, height: 1),

                    // [F] Row chọn ngày
                    TransactionDatePicker(
                      selectedDate: _transDate,
                      onChanged: (date) => setState(() => _transDate = date),
                    ),

                    const Divider(color: Colors.grey, height: 1),

                    // [G-debt] Row liên kết khoản nợ — chỉ hiện khi category là Thu nợ (21) hoặc Trả nợ (22)
                    if (_requiresDebtSelection) ...[
                      _buildDebtRow(),
                      const Divider(color: Colors.grey, height: 1),
                    ],

                    // Nút "THÊM CHI TIẾT"
                    _buildToggleDetailsButton(),

                    // Phần chi tiết (ẩn/hiện)
                    if (_showDetails) ...[
                      const Divider(color: Colors.grey, height: 1),
                      // [H] Row chọn sự kiện đang diễn ra — tái dùng EventProvider
                      _buildEventRow(),
                      const Divider(color: Colors.grey, height: 1),
                      // [I] Row đặt nhắc nhở — chọn ngày + giờ → lưu vào _reminderTime
                      _buildReminderRow(),
                      const Divider(color: Colors.grey, height: 1),
                      _buildWithPersonRow(),
                      const Divider(color: Colors.grey, height: 1),
                      _buildReportCheckbox(),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ===== Bàn phím tính toán — chỉ hiện khi user tap vào ô số tiền =====
            if (_isAmountFocused && !_isTextFieldFocused)
              _buildCalculatorKeyboard(),

            // ===== Nút LƯU =====
            _buildSaveButton(canSave),

            // ===== Nút XÓA =====
            _buildDeleteButton(),
          ],
        ),
      ),
    );
  }

  // ----- Widget: Row chọn ví -----
  Widget _buildWalletRow() {
    return GestureDetector(
      // [FIX-SOURCES] Disable tap khi đang load danh sách ví
      onTap: _isLoadingSources ? null : _showSourceBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon ví: loading spinner / icon ví đã chọn / placeholder
            if (_isLoadingSources)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                ),
              )
            else if (_selectedSourceItem != null)
              _buildSourceIcon(_selectedSourceItem!)
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isLoadingSources
                    ? 'Đang tải danh sách ví...'
                    : (_selectedSourceItem?.name ?? 'Chọn ví'),
                style: TextStyle(
                  color: (_isLoadingSources || _selectedSourceItem == null)
                      ? Colors.grey
                      : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            if (_isLoadingSources)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ----- Widget: Row liên kết sự kiện (trong phần THÊM CHI TIẾT) -----
  Widget _buildEventRow() {
    return GestureDetector(
      onTap: _showEventPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.event_note, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedEventDisplay ?? 'Chọn sự kiện (tuỳ chọn)',
                style: TextStyle(
                  color: _selectedEventId != null ? Colors.white : Colors.grey,
                  fontSize: 15,
                ),
              ),
            ),
            if (_selectedEventId != null)
              GestureDetector(
                onTap: () => setState(() {
                  _selectedEventId = null;
                  _selectedEventDisplay = null;
                }),
                child: const Icon(Icons.close, color: Colors.grey, size: 18),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ----- Widget: Row đặt nhắc nhở (DatePicker + TimePicker) -----
  // [I] Chọn ngày + giờ nhắc nhở → gộp thành _reminderTime (DateTime)
  //     → gửi lên server qua request.reminderDate
  //     → server tạo Notification với scheduledTime = reminderDate
  Widget _buildReminderRow() {
    return GestureDetector(
      onTap: _pickReminderDateTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.notifications_outlined, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _reminderTime != null
                    ? 'Nhắc nhở: ${FormatHelper.formatDisplayDate(_reminderTime!)} ${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
                    : 'Đặt nhắc nhở (tùy chọn)',
                style: TextStyle(
                  color: _reminderTime != null ? Colors.white : Colors.grey,
                  fontSize: 15,
                ),
              ),
            ),
            if (_reminderTime != null)
              GestureDetector(
                onTap: () => setState(() => _reminderTime = null),
                child: const Icon(Icons.close, color: Colors.grey, size: 18),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ----- Helper: Mở DatePicker → TimePicker → gộp thành DateTime -----
  Future<void> _pickReminderDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _reminderTime ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4CAF50),
              surface: Color(0xFF1C1C1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _reminderTime != null
          ? TimeOfDay.fromDateTime(_reminderTime!)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4CAF50),
              surface: Color(0xFF1C1C1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _reminderTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  // ----- Widget: Row liên kết khoản nợ (chỉ hiện khi category là Thu nợ/Trả nợ) -----
  Widget _buildDebtRow() {
    final isCollect = _selectedCategory?.id == 21;
    final hintText = isCollect
        ? 'Chọn khoản Cần Thu (tuỳ chọn)'
        : 'Chọn khoản Cần Trả (tuỳ chọn)';
    final iconColor = isCollect ? Colors.blue : Colors.orange;

    return GestureDetector(
      onTap: _showDebtPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDebtDisplay != null
                    ? _selectedDebtDisplay!
                    : hintText,
                style: TextStyle(
                  color: _selectedDebtId != null ? Colors.white : Colors.grey,
                  fontSize: 15,
                ),
              ),
            ),
            if (_selectedDebtId != null)
              GestureDetector(
                onTap: () => setState(() {
                  _selectedDebtId = null;
                  _selectedDebtDisplay = null;
                }),
                child: const Icon(Icons.close, color: Colors.grey, size: 18),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ----- Widget: Row ghi chú -----
  Widget _buildNoteRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.notes, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _noteController,
              focusNode: _noteFocusNode,
              maxLength: 500,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Thêm ghi chú',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----- Widget: Nút "THÊM CHI TIẾT" -----
  Widget _buildToggleDetailsButton() {
    return GestureDetector(
      onTap: () => setState(() => _showDetails = !_showDetails),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showDetails ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFF4CAF50),
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              _showDetails ? 'ẨN CHI TIẾT' : 'THÊM CHI TIẾT',
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----- Widget: Row "Với ai" -----
  Widget _buildWithPersonRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _withPersonController,
              focusNode: _withPersonFocusNode,
              maxLength: 100,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Với ai',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----- Widget: Checkbox "Không tính vào báo cáo" -----
  Widget _buildReportCheckbox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Checkbox(
            value: _notReportable,
            activeColor: const Color(0xFF4CAF50),
            onChanged: (value) => setState(() => _notReportable = value ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Không tính vào báo cáo',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  'Không tính giao dịch này trong báo cáo',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----- Widget: Bàn phím tính toán -----
  Widget _buildCalculatorKeyboard() {
    // [FIX-3] Phím nhanh — đơn vị VND thực tế, phổ biến nhất trong chi tiêu
    // [TODO] Khi tích hợp đa tiền tệ (USD/EUR): đổi values theo tỷ giá, label "$5" / "$10"
    final quickKeyValues = [50000.0, 100000.0, 200000.0, 300000.0, 500000.0, 1000000.0, 2000000.0];

    final mainKeys = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['000', '0', '.', '+'],
    ];

    return Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          // Hàng phím nhanh
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: quickKeyValues.map((value) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() => _amountStr = value.toInt().toString());
                    },
                    borderRadius: BorderRadius.circular(6),
                    splashColor: Colors.grey.withValues(alpha: 0.3),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        FormatHelper.formatShort(value),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 4 hàng phím chính
          ...mainKeys.map((row) {
            return Row(
              children: row.map((key) {
                final isOperator = ['+', '-', '×', '÷'].contains(key);
                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onKeyPressed(key),
                      splashColor: Colors.grey.withValues(alpha: 0.3),
                      highlightColor: Colors.grey.withValues(alpha: 0.15),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade800, width: 0.5),
                        ),
                        child: Text(
                          key,
                          style: TextStyle(
                            color: isOperator ? const Color(0xFF4CAF50) : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          }),

          // Hàng cuối: C | ⌫ | > (Enter)
          Row(
            children: [
              _buildSpecialKey('C', Colors.red),
              _buildSpecialKey('⌫', Colors.orange),
              Expanded(
                flex: 2,
                child: Material(
                  color: const Color(0xFF4CAF50),
                  child: InkWell(
                    onTap: () => _onKeyPressed('>'),
                    splashColor: Colors.white.withValues(alpha: 0.2),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      child: const Icon(Icons.check, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----- Widget: Phím đặc biệt (C, ⌫) -----
  Widget _buildSpecialKey(String key, Color color) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onKeyPressed(key),
          splashColor: color.withValues(alpha: 0.2),
          highlightColor: color.withValues(alpha: 0.1),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade800, width: 0.5),
            ),
            child: Text(
              key,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  // ----- Widget: Nút LƯU -----
  Widget _buildSaveButton(bool canSave) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ElevatedButton(
        onPressed: canSave ? _save : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canSave ? const Color(0xFF4CAF50) : Colors.grey[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                'LƯU',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  // ----- Widget: Nút XÓA -----
  Widget _buildDeleteButton() {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: OutlinedButton(
          onPressed: _isSaving ? null : _confirmDelete,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            'XÓA GIAO DỊCH',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // =============================================
  // _buildSourceIcon — hiển thị icon wallet/savinggoal
  // =============================================
  Widget _buildSourceIcon(SourceItem item) {
    final cloudinaryUrl = IconHelper.buildCloudinaryUrl(item.iconUrl);
    
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
        placeholder: (_, __) => _buildDefaultSourceIcon(item.type),
        errorWidget: (_, __, ___) => _buildDefaultSourceIcon(item.type),
      );
    }
    
    return _buildDefaultSourceIcon(item.type);
  }

  Widget _buildDefaultSourceIcon(String type) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: type == 'saving_goal'
            ? Colors.orange.shade400
            : Colors.green.shade400,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        type == 'saving_goal' ? Icons.savings : Icons.account_balance_wallet,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}
