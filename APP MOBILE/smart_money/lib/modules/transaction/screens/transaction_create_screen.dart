// ===========================================================
// [5] TransactionCreateScreen — Màn hình tạo giao dịch mới
// ===========================================================
// Layout:
//   • AppBar: nút X (đóng) + tiêu đề "Thêm giao dịch"
//   • [A] 3 tab selector: Khoản chi | Khoản thu | Vay/Nợ
//   • [B] Row chọn ví (wallet hoặc saving goal)
//   • [C] Row nhập số tiền (badge VND + số to)
//   • [D] Row chọn nhóm (navigate sang CategoryListScreen)
//   • [E] Row ghi chú (TextField)
//   • [F] Row chọn ngày (< ngày >)
//   • THÊM CHI TIẾT: [G] Với ai, [H] Sự kiện, [I] Nhắc nhở, [J] Báo cáo
//   • Nút LƯU cố định cuối màn hình
//
// Flow:
//   1. User chọn tab Chi/Thu/Vay → set _transactionType
//   2. User chọn ví → set _selectedSourceItem
//   3. User nhập số tiền → set _amountStr
//   4. User chọn nhóm → navigate CategoryListScreen → nhận CategoryResponse
//   5. User bấm Lưu → validate → gọi provider.createTransaction()
//   6. Thành công → Navigator.pop(context, true) — màn cha reload
//   7. Thất bại → hiện SnackBar đỏ + message lỗi từ server
//
// Lỗi từ server (copy từ GlobalExceptionHandler.java + TransactionServiceImpl):
//   • "Số tiền phải lớn hơn 0" (400 — validate amount)
//   • "Không tìm thấy ví" (400 — walletId không hợp lệ)
//   • "Không tìm thấy danh mục" (400 — categoryId không hợp lệ)
//   • "Dữ liệu không hợp lệ" (400 — @Valid fail)
//   • "Vui lòng chọn ngày hẹn trả cho khoản nợ." (400 — dueDate null khi tạo nợ mới)
//   • "Ngày hẹn trả phải là ngày trong tương lai." (400 — dueDate ở quá khứ)
//   • "Bạn không có quyền thực hiện thao tác này." (403)
// ===========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/transaction/models/request/transaction_request.dart';
import 'package:smart_money/modules/transaction/models/source_item.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_type_selector.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_date_picker.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_amount_field.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_category_row.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/modules/category/screens/category_list_screen.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/modules/event/providers/event_provider.dart';
import 'package:smart_money/modules/event/models/event_response.dart';
import 'package:smart_money/modules/debt/providers/debt_provider.dart';
import 'package:smart_money/modules/debt/models/debt_response.dart';

class TransactionCreateScreen extends StatefulWidget {
  // Ví mặc định — truyền từ dropdown đang chọn ở TransactionListScreen
  final SourceItem? initialSourceItem;
  // Tab mặc định — truyền từ DebtListScreen/DebtDetailScreen để pre-select Vay/Nợ
  final String? initialTransactionType; // 'expense' | 'income' | 'debt'
  // Category mặc định — truyền từ DebtDetailScreen để pre-select Thu nợ/Trả nợ
  final CategoryResponse? initialCategory;
  // Khoản nợ mặc định — truyền từ DebtDetailScreen để pre-fill debt
  final int? initialDebtId;
  final String? initialDebtDisplay;

  const TransactionCreateScreen({
    super.key,
    this.initialSourceItem,
    this.initialTransactionType,
    this.initialCategory,
    this.initialDebtId,
    this.initialDebtDisplay,
  });

  @override
  State<TransactionCreateScreen> createState() => _TransactionCreateScreenState();
}

class _TransactionCreateScreenState extends State<TransactionCreateScreen> {

  // =============================================
  // [5.1] STATE — Khai báo biến state
  // =============================================

  String _transactionType = 'expense';          // loại giao dịch: 'expense' | 'income' | 'debt'
  SourceItem? _selectedSourceItem;              // ví đã chọn (wallet hoặc saving goal)
  CategoryResponse? _selectedCategory;          // nhóm danh mục đã chọn
  String _amountStr = '0';                      // số tiền dạng string từ bàn phím
  final _noteController = TextEditingController(); // controller ô ghi chú
  DateTime _transDate = DateTime.now();          // ngày giao dịch — mặc định hôm nay
  bool _showDetails = false;                     // hiện/ẩn phần chi tiết bổ sung
  final _withPersonController = TextEditingController(); // controller "Với ai"
  int? _selectedEventId;                         // ID sự kiện đã chọn (nullable) — gửi lên server
  String? _selectedEventDisplay;                // tên sự kiện đã chọn — hiển thị trên UI
  int? _selectedDebtId;                          // ID khoản nợ đã chọn (nullable) — gửi lên server
  String? _selectedDebtDisplay;                 // tên/info khoản nợ đã chọn — hiển thị trên UI
  DateTime? _reminderTime;                       // nhắc nhở (nullable, phải > now)
  DateTime? _debtDueDate;                        // ngày hẹn trả nợ (nullable) — chỉ khi Cho vay/Đi vay
  bool _notReportable = false;                   // checkbox "Không tính vào báo cáo"
  bool _isSaving = false;                        // đang gửi request — disable nút Lưu
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
  // [5.1b] initState — đăng ký focus listeners
  // =============================================
  @override
  void initState() {
    super.initState();
    _noteFocusNode.addListener(_onFocusChanged);
    _withPersonFocusNode.addListener(_onFocusChanged);

    // [FIX-1] Nếu có ví mặc định từ dropdown → pre-fill
    // Bỏ qua "Tổng cộng" (type='all') vì tạo giao dịch cần ví cụ thể
    if (widget.initialSourceItem != null && widget.initialSourceItem!.type != 'all') {
      _selectedSourceItem = widget.initialSourceItem;
    }

    // [FIX-5] Pre-fill từ params truyền vào (từ DebtListScreen / DebtDetailScreen)
    if (widget.initialTransactionType != null) {
      _transactionType = widget.initialTransactionType!;
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory;
    }
    if (widget.initialDebtId != null) {
      _selectedDebtId = widget.initialDebtId;
      _selectedDebtDisplay = widget.initialDebtDisplay;
      _withPersonController.text = widget.initialDebtDisplay ?? '';
    }

    // [FIX-SOURCES] Đảm bảo sourceItems (ví + mục tiêu) đã được load.
    // Trường hợp mở từ DebtListScreen, DebtDetailScreen, hoặc FAB chưa qua
    // TransactionListScreen → provider.sourceItems có thể rỗng.
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
  // [5.2] dispose — giải phóng tài nguyên
  // =============================================
  @override
  void dispose() {
    _noteFocusNode.removeListener(_onFocusChanged);
    _withPersonFocusNode.removeListener(_onFocusChanged);
    _noteFocusNode.dispose();
    _withPersonFocusNode.dispose();
    _noteController.dispose();       // tránh memory leak
    _withPersonController.dispose();
    super.dispose();
  }

  // =============================================
  // [5.3] _save — xử lý khi bấm nút Lưu
  // =============================================
  // Gọi khi: User bấm nút "Lưu" ở cuối form
  Future<void> _save() async {
    // Bước 1: Validate client-side — kiểm tra nhóm + số tiền
    final amount = double.tryParse(_amountStr) ?? 0;
    if (amount <= 0) {
      _showSnackBar('Please enter an amount greater than 0.', isError: true);
      return;
    }
    if (_selectedCategory == null) {
      _showSnackBar('Please select a category group.', isError: true);
      return;
    }
    if (_selectedSourceItem == null) {
      _showSnackBar('Please select a wallet', isError: true);
      return;
    }

    // Bước 2: Validate nhắc nhở nếu có — phải là ngày tương lai
    if (_reminderTime != null && _reminderTime!.isBefore(DateTime.now())) {
      _showSnackBar('The reminder should be in the future.', isError: true);
      return;
    }

    // Bước 2a: Validate ngày hẹn trả nợ — bắt buộc khi TẠO nợ mới (Cho vay=19/Đi vay=20)
    // [NOTE] Backend cũng validate: dueDate null → 400, dueDate quá khứ → 400
    //        Frontend validate trước để tránh gọi API thừa
    final bool isCreatingNewDebt = _transactionType == 'debt'
        && !_requiresDebtSelection
        && _selectedDebtId == null;
    if (isCreatingNewDebt) {
      // Bắt buộc phải chọn ngày hẹn trả
      if (_debtDueDate == null) {
        _showSnackBar('Vui lòng chọn ngày hẹn trả cho khoản nợ.', isError: true);
        return;
      }
      // Ngày hẹn trả phải là ngày trong tương lai
      if (!_debtDueDate!.isAfter(DateTime.now())) {
        _showSnackBar('Ngày hẹn trả phải là ngày trong tương lai.', isError: true);
        return;
      }
    }

    // Bước 2b: Validate tên người — bắt buộc khi TẠO nợ mới (Cho vay=19/Đi vay=20)
    // [FIX] Bỏ qua khi Thu nợ (21)/Trả nợ (22) — đã chọn từ danh sách nợ có sẵn
    if (_transactionType == 'debt' && !_requiresDebtSelection) {
      final personName = _withPersonController.text.trim();
      if (personName.isEmpty) {
        _showSnackBar('Please enter the borrower/lender name.', isError: true);
        return;
      }
    }

    // Bước 3: Build request body — tương ứng TransactionRequest.java
    // [FIX-DUEDATE] Khi tạo nợ mới (Cho vay=19/Đi vay=20)
    // → gửi _debtDueDate riêng biệt với _reminderTime:
    //   - dueDate     → lưu vào tDebts.due_date (hiển thị trong Sổ nợ, gia hạn ở DebtEditScreen)
    //   - reminderDate → lưu vào tNotifications.scheduled_time (push notification nhắc nhở)
    // [NOTE] isCreatingNewDebt đã được khai báo ở Bước 2a — tái dùng biến cùng scope
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
      personName: _transactionType == 'debt' && !_requiresDebtSelection && _withPersonController.text.trim().isNotEmpty
          ? _withPersonController.text.trim()
          : null,
      eventId: _selectedEventId,
      debtId: _selectedDebtId,
      reminderDate: _reminderTime,
      // [FIX-DUEDATE] Gán ngày hẹn trả riêng biệt cho khoản nợ mới
      dueDate: isCreatingNewDebt ? _debtDueDate : null,
      reportable: !_notReportable,
    );

    // Bước 4: Gọi Provider (không gọi Service trực tiếp từ Screen)
    setState(() => _isSaving = true);
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final success = await provider.createTransaction(request);
    setState(() => _isSaving = false);

    // Bước 5: Kiểm tra mounted TRƯỚC KHI dùng context sau await
    if (!mounted) return;

    // Bước 6: Hiện kết quả
    if (success) {
      _showSnackBar(provider.successMessage ?? 'Successfully created the transaction.');
      Navigator.pop(context, true); // trả result=true để màn cha reload
    } else {
      _showSnackBar(provider.errorMessage ?? 'An error occurred.', isError: true);
    }
  }

  // =============================================
  // [5.4] _navigateToSelectCategory — mở màn chọn nhóm
  // =============================================
  // Gọi khi: User bấm vào dòng "Chọn nhóm"
  void _navigateToSelectCategory() async {
    final result = await Navigator.push<CategoryResponse>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryListScreen(
          isSelectMode: true,         // chế độ chọn — bấm vào category → pop trả về
          initialTab: _transactionType, // mở tab tương ứng (expense/income/debt)
        ),
      ),
    );

    // Nếu user chọn category → cập nhật state
    if (result != null && mounted) {
      final inferredType = _inferTabFromCategory(result);
      setState(() {
        _selectedCategory = result;
        // [FIX-1] Auto-switch tab để đồng bộ với category đã chọn
        // VD: đang ở Khoản Chi mà chọn "Cho vay" → tự đổi sang tab Vay/Nợ
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
  // [5.4b] _inferTabFromCategory — xác định tab từ category đã chọn
  // =============================================
  // IDs 19-22 (Cho vay, Đi vay, Thu nợ, Trả nợ) → 'debt'
  // ctgType=true → 'income', ctgType=false → 'expense'
  String _inferTabFromCategory(CategoryResponse category) {
    const debtIds = {19, 20, 21, 22};
    if (debtIds.contains(category.id)) return 'debt';
    return (category.ctgType == true) ? 'income' : 'expense';
  }

  // =============================================
  // [5.5] _showSourceBottomSheet — mở bottom sheet chọn ví
  // =============================================
  // Gọi khi: User bấm vào dòng chọn ví
  void _showSourceBottomSheet() {
    // Guard: đang tải thì không mở
    if (_isLoadingSources) return;

    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final sources = provider.sourceItems;

    // Lọc bỏ item "Tổng cộng" — khi tạo giao dịch phải chọn ví cụ thể
    final selectableSources = sources.where((s) => s.type != 'all').toList();

    // Nếu chưa có ví nào → hiện thông báo
    if (selectableSources.isEmpty) {
      _showSnackBar('No wallets were found. Please create a wallet first.', isError: true);
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
              // Icon ví — convert URL nếu cần + fallback color icon
              leading: _buildSourceIcon(item),
              // Tên ví
              title: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.green : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              // Số dư
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
  // [5.6] Helper getters — xác định trạng thái nợ
  // =============================================

  // true khi category là Thu nợ (21) hoặc Trả nợ (22) — hiện row liên kết khoản nợ
  bool get _requiresDebtSelection =>
      _selectedCategory?.id == 21 || _selectedCategory?.id == 22;

  // debtType truyền vào picker:
  //   Thu nợ (21) → CẦN THU (debtType=true)
  //   Trả nợ (22) → CẦN TRẢ (debtType=false)
  bool get _debtTypeForPicker => _selectedCategory?.id == 21;

  // =============================================
  // [5.7] _showEventPicker — bottom sheet chọn sự kiện đang diễn ra
  // =============================================
  // Gọi khi: User bấm vào dòng "Chọn sự kiện" trong phần chi tiết
  // API: GET /api/events?isFinished=false (tái dùng EventProvider)
  Future<void> _showEventPicker() async {
    // Bước 1: Load danh sách sự kiện đang diễn ra (isFinished=false)
    // [FIX-2] forceRefresh=true để luôn lấy totals mới nhất từ server
    // (cache cũ không phản ánh giao dịch vừa được thêm vào sự kiện)
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    await eventProvider.loadEvents(false, forceRefresh: true);

    // Bước 2: Kiểm tra mounted sau await
    if (!mounted) return;

    final events = eventProvider.events;

    // Bước 3: Hiện bottom sheet danh sách sự kiện
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
                      'Select the ongoing event',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    // Nút "Bỏ chọn" nếu đang có sự kiện được chọn
                    if (_selectedEventId != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedEventId = null;
                            _selectedEventDisplay = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Deselect', style: TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey, height: 1),

              // Danh sách sự kiện hoặc thông báo trống
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No events are currently taking place.',
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
                              'To ${FormatHelper.formatDate(event.endDate)}',
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Income: ${FormatHelper.formatShort(event.totalIncome)}',
                                  style: const TextStyle(color: Colors.green, fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Expense: ${FormatHelper.formatShort(event.totalExpense)}',
                                  style: const TextStyle(color: Colors.red, fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Remaining: ${FormatHelper.formatShort(event.netAmount)}',
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
                          // Chọn sự kiện → cập nhật ID và tên hiển thị
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
  // [5.8] _showDebtPicker — bottom sheet chọn khoản nợ
  // =============================================
  // Gọi khi: User bấm vào dòng "Chọn khoản nợ" (chỉ khi category là Thu nợ/Trả nợ)
  // API: GET /api/debts?debtType=false|true (tái dùng DebtProvider)
  // Tham số debtType phụ thuộc vào category:
  //   Thu nợ (21) → debtType=true (CẦN THU — Cho vay)
  //   Trả nợ (22) → debtType=false (CẦN TRẢ — Đi vay)
  Future<void> _showDebtPicker() async {
    // Bước 1: Load khoản nợ phù hợp
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
    final debtType = _debtTypeForPicker;
    await debtProvider.loadDebts(debtType);

    // Bước 2: Kiểm tra mounted sau await
    if (!mounted) return;

    // Bước 3: Lấy danh sách chưa hoàn thành theo loại
    // Thu nợ (21) → dùng receivableDebts (CẦN THU, chưa thu)
    // Trả nợ (22) → dùng payableDebts (CẦN TRẢ, chưa trả)
    final debts = debtType
        ? debtProvider.receivableDebts  // CẦN THU — Cho vay chưa thu
        : debtProvider.payableDebts;    // CẦN TRẢ — Đi vay chưa trả

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
              // Header
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
                      'Choose the $tabLabel',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    // Nút "Bỏ chọn" nếu đang liên kết khoản nợ
                    if (_selectedDebtId != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDebtId = null;
                            _selectedDebtDisplay = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Deselect', style: TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey, height: 1),

              // Danh sách khoản nợ hoặc thông báo trống
              if (debts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'There are no incomplete $tabLabel entries',
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
                        // Tên người vay/cho vay
                        title: Text(
                          debt.personName,
                          style: TextStyle(
                            color: isSelected
                                ? (debtType ? Colors.blue : Colors.orange)
                                : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        // Còn lại bao nhiêu
                        subtitle: Text(
                          'Remaining: ${FormatHelper.formatVND(debt.remainAmount)}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: debtType ? Colors.blue : Colors.orange)
                            : null,
                        onTap: () {
                          // Chọn khoản nợ → cập nhật ID, tên hiển thị
                          // [FIX] Auto-fill withPerson từ tên người trong khoản nợ đã chọn
                          // (backend lấy person_name từ debt record, withPerson chỉ là ghi chú thêm)
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
  // [5.6] Helper — xử lý bấm phím trên bàn phím tính toán
  // =============================================
  void _onKeyPressed(String key) {
    setState(() {
      switch (key) {
        case 'C':
          // Reset tất cả về 0
          _amountStr = '0';
          _pendingOperator = '';
          _previousValue = 0;
          _waitingForNextNumber = false;
          break;

        case '⌫':
          // Xóa ký tự cuối — nếu đang chờ nhập số mới thì bỏ qua
          if (_waitingForNextNumber) break;
          if (_amountStr.length > 1) {
            _amountStr = _amountStr.substring(0, _amountStr.length - 1);
          } else {
            _amountStr = '0';
          }
          break;

        case '000':
          // Thêm 000 — nếu đang chờ nhập số mới thì bắt đầu từ 000 (= 0)
          if (_waitingForNextNumber) {
            _waitingForNextNumber = false;
            // 000 khi bắt đầu = 0, không thay đổi
          } else if (_amountStr != '0') {
            _amountStr += '000';
          }
          break;

        case '.':
          // [FIX] Chỉ cho thêm 1 dấu chấm duy nhất
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
          // [FIX-4] Bấm toán tử:
          //   1. Nếu đã có toán tử chờ VÀ user đã nhập số mới → tính trung gian
          //   2. Lưu toán tử mới → chờ user nhập số tiếp theo
          //   3. KHÔNG reset _amountStr ngay — giữ hiển thị để user thấy
          if (_pendingOperator.isNotEmpty && !_waitingForNextNumber) {
            // User đã nhập số mới sau toán tử trước → tính kết quả trung gian
            final current = double.tryParse(_amountStr) ?? 0;
            _previousValue = _calcResult(_previousValue, current, _pendingOperator);
            _amountStr = _formatCalcResult(_previousValue);
          } else {
            // Lần đầu bấm toán tử hoặc bấm toán tử liên tiếp
            _previousValue = double.tryParse(_amountStr) ?? 0;
          }
          _pendingOperator = key;
          _waitingForNextNumber = true; // chờ user nhập số mới, giữ _amountStr hiển thị
          break;

        case '>':
          // Tính kết quả cuối cùng (nút =)
          if (_pendingOperator.isNotEmpty && !_waitingForNextNumber) {
            final current = double.tryParse(_amountStr) ?? 0;
            final result = _calcResult(_previousValue, current, _pendingOperator);
            _amountStr = _formatCalcResult(result);
            _pendingOperator = '';
            _previousValue = 0;
            _waitingForNextNumber = false;
          }
          // [FIX-3] Ẩn bàn phím sau khi bấm ✓ — số tiền đã xác nhận xong
          _isAmountFocused = false;
          break;

        default:
          // Bấm số 0-9
          if (_waitingForNextNumber) {
            // [FIX-4] User bắt đầu nhập số mới sau toán tử
            _amountStr = key; // thay thế hoàn toàn
            _waitingForNextNumber = false;
          } else if (_amountStr == '0') {
            _amountStr = key; // thay thế số 0 đầu
          } else {
            _amountStr += key; // nối thêm
          }
          break;
      }
    });
  }

  // [FIX] Tính kết quả phép tính — dùng chung cho operator chaining và '>'
  double _calcResult(double a, double b, String op) {
    switch (op) {
      case '+': return a + b;
      case '-': return a - b;
      case '×': return a * b;
      case '÷': return b != 0 ? a / b : 0;
      default:  return b;
    }
  }

  // [FIX] Format kết quả: nếu là số nguyên thì bỏ .0, nếu có thập phân thì giữ
  String _formatCalcResult(double value) {
    if (value == value.toInt().toDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  // =============================================
  // [5.7] Helper — hiện SnackBar
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
  // [5.8] build — giao diện chính
  // =============================================
  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountStr) ?? 0;
    // Nút Lưu chỉ enable khi: đã chọn nhóm + số tiền > 0 + đã chọn ví + không đang lưu
    final canSave = _selectedCategory != null &&
        amount > 0 &&
        _selectedSourceItem != null &&
        !_isSaving;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 0,
        // Nút X (đóng, không phải back)
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add transaction',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        // Bấm vùng trống → unfocus text field + ẩn calculator keyboard
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
                      // [IMPORTANT] Khi ví là SavingGoal → ẩn tab Vay/Nợ
                      showDebtTab: _selectedSourceItem?.type != 'saving_goal',
                      onChanged: (type) {
                        setState(() {
                          _transactionType = type;
                          // Reset nhóm khi đổi tab vì nhóm thuộc loại khác
                          _selectedCategory = null;
                          // [FIX-DUEDATE] Reset ngày hẹn trả khi đổi tab (chỉ dùng cho debt)
                          _debtDueDate = null;
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
                        FocusScope.of(context).unfocus(); // tắt text field focus trước
                        setState(() => _isAmountFocused = true); // hiện calculator
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
                    // Thu nợ (21): dùng danh sách CẦN THU (cho vay chưa thu)
                    // Trả nợ (22): dùng danh sách CẦN TRẢ (đi vay chưa trả)
                    if (_requiresDebtSelection) ...[
                      _buildDebtRow(),
                      const Divider(color: Colors.grey, height: 1),
                    ],

                    // [G] Row "Tên người" — bắt buộc khi TẠO nợ mới (Cho vay=19/Đi vay=20)
                    // [FIX] KHÔNG hiện khi Thu nợ/Trả nợ (21/22) — tên lấy từ khoản nợ đã chọn
                    if (_transactionType == 'debt' && !_requiresDebtSelection)
                      _buildDebtPersonNameRow(),

                    if (_transactionType == 'debt' && !_requiresDebtSelection)
                      const Divider(color: Colors.grey, height: 1),

                    // [G2-debt] Row chọn ngày hẹn trả — chỉ hiện khi TẠO nợ mới (Cho vay=19/Đi vay=20)
                    // Ngày này lưu vào tDebts.due_date — khác với reminder (lưu vào tNotifications)
                    if (_transactionType == 'debt' && !_requiresDebtSelection) ...[
                      _buildDebtDueDateRow(),
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
                      if (_transactionType != 'debt')
                        _buildWithPersonRow(),
                      if (_transactionType != 'debt')
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
          ],
        ),
      ),
    );
  }

  // ----- Widget: Row chọn ví -----
  Widget _buildWalletRow() {
    return GestureDetector(
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
                    ? 'Loading wallet list...'
                    : (_selectedSourceItem?.name ?? 'Choose a wallet'),
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
                // Hiện tên sự kiện đã chọn hoặc placeholder
                _selectedEventDisplay ?? 'Select event (optional)',
                style: TextStyle(
                  color: _selectedEventId != null ? Colors.white : Colors.grey,
                  fontSize: 15,
                ),
              ),
            ),
            // Nút xóa chọn sự kiện
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
    // Nhãn phụ theo loại category
    final isCollect = _selectedCategory?.id == 21; // Thu nợ → CẦN THU
    final hintText = isCollect
        ? 'Select the amount of debt to be collected (optional)'
        : 'Select the amount of debt to be repaid (optional)';
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
                // Hiện tên khoản nợ đã chọn hoặc placeholder
                _selectedDebtDisplay != null
                    ? _selectedDebtDisplay!
                    : hintText,
                style: TextStyle(
                  color: _selectedDebtId != null ? Colors.white : Colors.grey,
                  fontSize: 15,
                ),
              ),
            ),
            // Nút xóa chọn khoản nợ
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
                 hintText: 'Add a note',
                 hintStyle: TextStyle(color: Colors.grey),
                 border: InputBorder.none,
                 counterText: '', // ẩn counter ký tự
               ),
             ),
           ),
         ],
       ),
     );
   }

   // ----- Widget: Row "Tên người vay/cho vay" — Bắt buộc khi debt -----
   Widget _buildDebtPersonNameRow() {
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
       child: Row(
         children: [
           const Icon(Icons.person, color: Colors.orange, size: 20),
           const SizedBox(width: 12),
           Expanded(
             child: TextField(
               controller: _withPersonController,
               focusNode: _withPersonFocusNode,
               maxLength: 100,
               style: const TextStyle(color: Colors.white, fontSize: 15),
               decoration: InputDecoration(
                 hintText: _transactionType == 'debt'
                     ? 'Borrower/Lender name *'
                     : 'With person',
                 hintStyle: const TextStyle(color: Colors.grey),
                 border: InputBorder.none,
                 counterText: '',
               ),
             ),
           ),
         ],
       ),
     );
   }

  // ----- Widget: Row chọn ngày hẹn trả nợ (dueDate) -----
  // Chỉ hiện khi TẠO nợ mới (Cho vay=19/Đi vay=20)
  // [REQUIRED] Bắt buộc nhập — backend validate null → 400, quá khứ → 400
  // Khác với reminder: dueDate lưu vào tDebts.due_date, reminder lưu vào tNotifications
  Widget _buildDebtDueDateRow() {
    return GestureDetector(
      onTap: _pickDebtDueDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.event_available, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _debtDueDate != null
                    ? 'Hạn trả: ${_debtDueDate!.day.toString().padLeft(2, '0')}/'
                        '${_debtDueDate!.month.toString().padLeft(2, '0')}/'
                        '${_debtDueDate!.year}'
                    // [REQUIRED] Đổi hint thành bắt buộc — có dấu * và màu cam
                    : 'Chọn ngày hẹn trả *',
                style: TextStyle(
                  // Màu đỏ nhạt khi chưa chọn để nhắc nhở bắt buộc
                  color: _debtDueDate != null ? Colors.white : Colors.orangeAccent,
                  fontSize: 15,
                ),
              ),
            ),
            if (_debtDueDate != null)
              GestureDetector(
                onTap: () => setState(() => _debtDueDate = null),
                child: const Icon(Icons.close, color: Colors.grey, size: 18),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ----- Helper: Mở DatePicker cho ngày hẹn trả nợ -----
  // Chỉ cho chọn ngày tương lai (không chọn quá khứ)
  // Gán giờ cuối ngày (23:59:59) để khớp logic backend
  Future<void> _pickDebtDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _debtDueDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      helpText: 'Chọn ngày hẹn trả',
      confirmText: 'Xác nhận',
      cancelText: 'Hủy',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF9800), // orange cho debt
              surface: Color(0xFF1C1C1E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        // Gán 23:59:59 để "hạn cuối ngày" — khớp với DebtEditScreen
        _debtDueDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
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
              _showDetails ? 'HIDE DETAILS' : 'MORE DETAILS',
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
                hintText: 'With person',
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
                  'Not included in the report.',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  'This transaction is not included in the report.',
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
    // Format dùng FormatHelper.formatShort() → "50k", "100k", "1tr", "2tr"
    final quickKeyValues = [50000.0, 100000.0, 200000.0, 300000.0, 500000.0, 1000000.0, 2000000.0, 3000000.0, 5000000.0, 10000000.0];

    // 4 hàng bàn phím chính
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
                        FormatHelper.formatShort(value), // "50k", "1tr"
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
                  // [FIX] Dùng Material + InkWell thay GestureDetector → có hiệu ứng ripple khi bấm
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
                // [FIX] Dùng Material + InkWell → hiệu ứng ripple khi bấm Enter
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
      // [FIX] Dùng Material + InkWell → hiệu ứng ripple khi bấm
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
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
