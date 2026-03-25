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

class TransactionCreateScreen extends StatefulWidget {
  // Ví mặc định — truyền từ dropdown đang chọn ở TransactionListScreen
  final SourceItem? initialSourceItem;

  const TransactionCreateScreen({super.key, this.initialSourceItem});

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
  int? _selectedEventId;                         // sự kiện đã chọn (nullable)
  DateTime? _reminderTime;                       // nhắc nhở (nullable, phải > now)
  bool _notReportable = false;                   // checkbox "Không tính vào báo cáo"
  bool _isSaving = false;                        // đang gửi request — disable nút Lưu
  String _pendingOperator = '';                   // toán tử đang chờ (+, -, ×, ÷)
  double _previousValue = 0;                     // giá trị trước toán tử
  bool _waitingForNextNumber = false;             // [FIX-4] true = vừa bấm toán tử, chờ user nhập số mới

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
  }

  void _onFocusChanged() {
    final focused = _noteFocusNode.hasFocus || _withPersonFocusNode.hasFocus;
    if (focused != _isTextFieldFocused) {
      setState(() => _isTextFieldFocused = focused);
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

    // Bước 2: Validate nhắc nhở nếu có — phải là ngày tương lai
    if (_reminderTime != null && _reminderTime!.isBefore(DateTime.now())) {
      _showSnackBar('Nhắc nhở phải là thời gian tương lai', isError: true);
      return;
    }

    // Bước 3: Build request body — tương ứng TransactionRequest.java
    final request = TransactionRequest(
      // Nếu ví là wallet → gửi walletId, nếu là saving_goal → gửi goalId
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
      reminderDate: _reminderTime,
      reportable: !_notReportable, // checkbox "Không tính" → reportable = false
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
      _showSnackBar(provider.successMessage ?? 'Tạo giao dịch thành công');
      Navigator.pop(context, true); // trả result=true để màn cha reload
    } else {
      _showSnackBar(provider.errorMessage ?? 'Có lỗi xảy ra', isError: true);
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
      setState(() {
        _selectedCategory = result;
      });
    }
  }

  // =============================================
  // [5.5] _showSourceBottomSheet — mở bottom sheet chọn ví
  // =============================================
  // Gọi khi: User bấm vào dòng chọn ví
  void _showSourceBottomSheet() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final sources = provider.sourceItems;

    // Lọc bỏ item "Tổng cộng" — khi tạo giao dịch phải chọn ví cụ thể
    final selectableSources = sources.where((s) => s.type != 'all').toList();

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
                  // [IMPORTANT] Nếu đổi ví sang SavingGoal → ẩn tab Vay/Nợ
                  // vì SavingGoal chỉ cho phép một số category nhất định
                  if (item.type == 'saving_goal') {
                    _selectedCategory = null;
                  }
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
          'Thêm giao dịch',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        // Bấm vùng trống → unfocus text field → hiện lại calculator keyboard
        onTap: () {
          FocusScope.of(context).unfocus();
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
                        });
                      },
                    ),

                    const Divider(color: Colors.grey, height: 1),

                    // [B] Row chọn ví
                    _buildWalletRow(),

                    const Divider(color: Colors.grey, height: 1),

                    // [C] Row hiển thị số tiền
                    TransactionAmountField(
                      amount: _amountStr,
                      transactionType: _transactionType,
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

                    // Nút "THÊM CHI TIẾT"
                    _buildToggleDetailsButton(),

                    // Phần chi tiết (ẩn/hiện)
                    if (_showDetails) ...[
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

            // ===== Bàn phím tính toán — ẩn khi đang focus text field =====
            if (!_isTextFieldFocused)
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
      onTap: _showSourceBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon ví đã chọn (hoặc placeholder)
            _selectedSourceItem != null
                ? _buildSourceIcon(_selectedSourceItem!)
                : Container(
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
                _selectedSourceItem?.name ?? 'Chọn ví',
                style: TextStyle(
                  color: _selectedSourceItem != null ? Colors.white : Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
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
                counterText: '', // ẩn counter ký tự
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
    // Hàng phím nhanh
    final quickKeys = ['10', '50', '100', '500', '1000', '5000'];

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
              children: quickKeys.map((key) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() => _amountStr = key);
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
                        FormatHelper.formatNumber(double.parse(key)),
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
