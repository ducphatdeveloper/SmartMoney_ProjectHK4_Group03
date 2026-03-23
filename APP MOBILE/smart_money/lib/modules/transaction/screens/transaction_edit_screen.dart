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
  int? _selectedEventId;                         // sự kiện đã chọn (nullable)
  DateTime? _reminderTime;                       // nhắc nhở (nullable, phải > now)
  bool _notReportable = false;                   // checkbox "Không tính vào báo cáo"
  bool _isSaving = false;                        // đang gửi request — disable nút Lưu/Xóa
  String _pendingOperator = '';                   // toán tử đang chờ (+, -, ×, ÷)
  double _previousValue = 0;                     // giá trị trước toán tử

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

    // Pre-fill "Không tính vào báo cáo"
    _notReportable = !tx.reportable;

    // Nếu có chi tiết bổ sung → mở sẵn
    if (tx.withPerson != null || tx.eventId != null || !tx.reportable) {
      _showDetails = true;
    }
  }

  void _onFocusChanged() {
    final focused = _noteFocusNode.hasFocus || _withPersonFocusNode.hasFocus;
    if (focused != _isTextFieldFocused) {
      setState(() => _isTextFieldFocused = focused);
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
      setState(() {
        _selectedCategory = result;
      });
    }
  }

  // =============================================
  // [6.6b] _showSourceBottomSheet — mở bottom sheet chọn ví
  // =============================================
  void _showSourceBottomSheet() {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final sources = provider.sourceItems;

    // Lọc bỏ item "Tổng cộng" — khi sửa giao dịch phải chọn ví cụ thể
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
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.type == 'saving_goal'
                      ? Colors.orange.shade400
                      : Colors.green.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.type == 'saving_goal' ? Icons.savings : Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 22,
                ),
              ),
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
  // [6.7] _onKeyPressed — xử lý bàn phím tính toán
  // =============================================
  void _onKeyPressed(String key) {
    setState(() {
      switch (key) {
        case 'C':
          _amountStr = '0';
          _pendingOperator = '';
          _previousValue = 0;
          break;

        case '⌫':
          if (_amountStr.length > 1) {
            _amountStr = _amountStr.substring(0, _amountStr.length - 1);
          } else {
            _amountStr = '0';
          }
          break;

        case '000':
          if (_amountStr != '0') {
            _amountStr += '000';
          }
          break;

        case '.':
          // [FIX] Chỉ cho thêm 1 dấu chấm duy nhất
          if (!_amountStr.contains('.')) {
            _amountStr += '.';
          }
          break;

        case '+':
        case '-':
        case '×':
        case '÷':
          // [FIX] Nếu đang có toán tử chờ → tính kết quả trung gian trước
          if (_pendingOperator.isNotEmpty && _amountStr != '0') {
            final current = double.tryParse(_amountStr) ?? 0;
            _previousValue = _calcResult(_previousValue, current, _pendingOperator);
            _amountStr = _formatCalcResult(_previousValue);
          } else {
            _previousValue = double.tryParse(_amountStr) ?? 0;
          }
          _pendingOperator = key;
          _amountStr = '0';
          break;

        case '>':
          if (_pendingOperator.isNotEmpty) {
            final current = double.tryParse(_amountStr) ?? 0;
            final result = _calcResult(_previousValue, current, _pendingOperator);
            _amountStr = _formatCalcResult(result);
            _pendingOperator = '';
            _previousValue = 0;
          }
          break;

        default:
          if (_amountStr == '0') {
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
      onTap: _showSourceBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              _selectedSourceItem?.type == 'saving_goal'
                  ? Icons.savings
                  : Icons.account_balance_wallet_outlined,
              color: Colors.grey,
              size: 20,
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
    final quickKeys = ['10', '50', '100', '500', '1000', '5000'];

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
}

