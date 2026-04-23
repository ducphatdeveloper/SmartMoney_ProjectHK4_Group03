// ===========================================================
// [8] DebtDetailScreen — Chi tiết một khoản nợ
// ===========================================================
// Trách nhiệm:
//   • Hiển thị tổng / đã trả / còn lại + thanh tiến trình
//   • Hiển thị lịch sử giao dịch liên quan (flat list)
//   • Cho phép: Sửa thông tin, Toggle trạng thái, Xóa khoản nợ
//   • Nút "THÊM GIAO DỊCH TRẢ NỢ" → navigate sang Transaction create
//
// Layout:
//   • AppBar: "← Tên người" + icon [✏️] [🗑️]
//   • Card tóm tắt: Tổng nợ / Đã trả / Còn lại / Hạn trả
//   • LinearProgressIndicator
//   • Nút "THÊM GIAO DỊCH TRẢ NỢ" / "THÊM GIAO DỊCH THU NỢ"
//   • Section "Lịch sử giao dịch" — ListView các TransactionResponse
//   • Nút "Đánh dấu hoàn thành" / "Đánh dấu chưa hoàn thành"
//
// Flow:
//   1. initState → provider.loadDetail(debtId)
//   2. Tap ✏️ → push DebtEditScreen → await → loadDetail lại
//   3. Tap 🗑️ → Dialog xác nhận → provider.deleteDebt() → pop(true)
//   4. Tap toggle → provider.toggleStatus() → cập nhật UI
//   5. Tap "THÊM GIAO DỊCH" → navigate TransactionCreateScreen với debtId
//
// Lỗi từ server:
//   • "Khoản nợ không tồn tại hoặc bạn không có quyền truy cập." (403)
//
// Gọi từ:
//   • DebtListScreen → push khi user tap vào DebtCardWidget
// ===========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/modules/transaction/models/merge/transaction_list_response.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/transaction/screens/transaction_create_screen.dart';
import 'package:smart_money/modules/transaction/screens/transaction_edit_screen.dart';
import 'package:smart_money/modules/transaction/services/transaction_service.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_day_group.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_detail_sheet.dart';
import '../providers/debt_provider.dart';
import 'debt_edit_screen.dart';

class DebtDetailScreen extends StatefulWidget {

  final int debtId;    // ID khoản nợ cần tải chi tiết
  final bool debtType; // false=CẦN TRẢ, true=CẦN THU (dùng cho màu sắc UI)

  const DebtDetailScreen({
    super.key,
    required this.debtId,
    required this.debtType,
  });

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {

  // =============================================
  // [8.1] STATE
  // =============================================

  bool _hasChanges = false; // theo dõi xem có thay đổi không để pop(true) về List

  // =============================================
  // [8.2] LIFECYCLE
  // =============================================

  @override
  void initState() {
    super.initState();
    // Tải chi tiết + giao dịch ngay khi vào màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebtProvider>().loadDetail(context, widget.debtId);
    });
  }

  @override
  void dispose() {
    // [IMPORTANT] Clear state chi tiết khi rời màn hình để tránh hiện data cũ
    context.read<DebtProvider>().clearDetail();
    super.dispose();
  }

  // =============================================
  // [8.3] ACTIONS
  // =============================================

  // Mở màn hình sửa, reload chi tiết nếu user lưu thành công
  Future<void> _openEdit() async {
    final provider = context.read<DebtProvider>();
    final debt = provider.currentDebt;
    if (debt == null) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: DebtEditScreen(debtId: debt.id, debtType: debt.debtType),
        ),
      ),
    );

    if (saved == true && mounted) {
      // Reload chi tiết sau khi sửa — currentDebt đã được update trong provider
      _hasChanges = true;
      await provider.loadDetail(context, widget.debtId);
    }
  }

  // Dialog xác nhận xóa
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Do you want to delete your debt?'),
        content: const Text(
          'The debt will be delete.'
          'Related transactions will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Bước: Gọi provider.deleteDebt → pop về list
    final success = await context
        .read<DebtProvider>()
        .deleteDebt(context, widget.debtId, widget.debtType);

    if (!mounted) return;
    if (success) {
      // Pop về DebtListScreen với true để list biết cần reload
      Navigator.pop(context, true);
    } else {
      _showError(context.read<DebtProvider>().errorMessage);
    }
  }

  // Toggle trạng thái finished
  Future<void> _toggleStatus() async {
    final success = await context
        .read<DebtProvider>()
        .toggleStatus(context, widget.debtId);

    if (!mounted) return;
    if (success) {
      _hasChanges = true; // Báo list phải reload
    } else {
      _showError(context.read<DebtProvider>().errorMessage);
    }
  }

  // [FIX-5] Mở TransactionCreateScreen với tab Vay/Nợ + category + debt pre-filled
  // debtType=false (CẦN TRẢ) → categoryId=22 (Trả nợ)
  // debtType=true  (CẦN THU) → categoryId=21 (Thu nợ)
  Future<void> _openAddTransaction() async {
    final provider = context.read<DebtProvider>();
    final debt = provider.currentDebt;
    if (debt == null) return;

    // Bước 1: Tạo CategoryResponse pre-selected
    // Thu nợ (21) = income (ctgType=true), Trả nợ (22) = expense (ctgType=false)
    final preCategory = CategoryResponse(
      id: widget.debtType ? 21 : 22,
      ctgName: widget.debtType ? 'Debt collection' : 'Pay off the debt.',
      ctgType: widget.debtType,
    );

    // Bước 2: Navigate sang TransactionCreateScreen
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionCreateScreen(
          initialTransactionType: 'debt',    // pre-select tab Vay/Nợ
          initialCategory: preCategory,      // pre-select Thu nợ / Trả nợ
          initialDebtId: widget.debtId,      // pre-fill khoản nợ này
          initialDebtDisplay: debt.personName, // tên người nợ
        ),
      ),
    );

    // Bước 3: Nếu tạo thành công → reload detail để cập nhật remainAmount
    if (result == true && mounted) {
      _hasChanges = true;
      await provider.loadDetail(context, widget.debtId);

      // [FIX] Kiểm tra sau khi reload: nếu debt không còn tồn tại (bị backend
      // xóa tự động vì không có giao dịch gốc hợp lệ), quay lại list thay vì
      // bị kẹt ở màn hình lỗi với message "Bạn không có quyền truy cập".
      if (mounted && provider.currentDebt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The debt has been settled or no longer exists.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true); // refresh DebtListScreen
      }
    }
  }

  void _showError(String? msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg ?? 'An error has occurred.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // =============================================
  // [8.4] BUILD
  // =============================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Pop với true nếu có thay đổi để DebtListScreen reload
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _hasChanges) {
          // [NOTE] Đã được xử lý khi Navigator.pop(context, _hasChanges) gọi thủ công
        }
      },
      child: Consumer<DebtProvider>(
        builder: (context, provider, _) {
          final debt = provider.currentDebt;

          return Scaffold(
            appBar: AppBar(
              title: Text(debt?.personName ?? 'Debt details'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context, _hasChanges),
              ),
              actions: [
                // Nút sửa — chỉ hiện khi đã load xong
                if (debt != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit information',
                    onPressed: provider.isSaving ? null : _openEdit,
                  ),
                // Nút xóa
                if (debt != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete debt',
                    color: Colors.red[400],
                    onPressed: provider.isDeleting ? null : _confirmDelete,
                  ),
              ],
            ),

            body: provider.isLoadingDetail
                // Đang tải → spinner
                ? const Center(child: CircularProgressIndicator())
                : debt == null
                    // Không có data → lỗi
                    ? _buildErrorState(provider.errorMessage)
                    // Có data → nội dung chính
                    : _buildContent(provider),
          );
        },
      ),
    );
  }

  // Nội dung chính khi đã có data
  Widget _buildContent(DebtProvider provider) {
    final debt = provider.currentDebt!;
    // Màu chủ đạo: đỏ cho Cần Trả, xanh cho Cần Thu
    final mainColor = widget.debtType ? Colors.blue[600]! : Colors.red[600]!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ----- Card tóm tắt số tiền -----
        _buildAmountCard(debt, mainColor),
        const SizedBox(height: 16),

        // ----- Nút THÊM GIAO DỊCH -----
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openAddTransaction,
            icon: const Icon(Icons.add),
            label: Text(
              widget.debtType
                  ? 'ADD DEBT COLLECTION TRANSACTION'
                  : 'ADD DEBT REPAYMENT TRANSACTION',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ----- Nút toggle trạng thái -----
        _buildToggleStatusButton(provider, debt.finished),
        const SizedBox(height: 24),

        // ----- Section Lịch sử giao dịch -----
        _DebtTransactionSection(
          debtId: widget.debtId,
          onTransactionChanged: () async {
            _hasChanges = true;
            await context.read<DebtProvider>().loadDetail(context, widget.debtId);
          },
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  // Card hiển thị Tổng / Đã trả / Còn lại + progress bar + hạn trả
  Widget _buildAmountCard(dynamic debt, Color mainColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 3 cột: Tổng nợ | Đã trả/thu | Còn lại
          Row(
            children: [
              _buildAmountCell('Total debt',
                  FormatHelper.formatVND(debt.totalAmount), Colors.grey[700]!),
              _buildDivider(),
              _buildAmountCell(
                  widget.debtType ? 'Debt collected' : 'Debt has been repaid.',
                  FormatHelper.formatVND(debt.paidAmount),
                  Colors.green[600]!),
              _buildDivider(),
              _buildAmountCell(
                  'Remaining',
                  FormatHelper.formatVND(debt.remainAmount),
                  mainColor),
            ],
          ),

          const SizedBox(height: 14),

          // Thanh tiến trình
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: debt.progress,
              backgroundColor: Colors.grey[200],
              color: debt.finished ? Colors.green : mainColor,
              minHeight: 8,
            ),
          ),

          // Phần trăm + label trạng thái
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(debt.progress * 100).toStringAsFixed(0)}% complete',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (debt.finished)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '✅ Complete',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),

          // Hạn trả (nếu có)
          if (debt.dueDate != null) ...[
            const SizedBox(height: 10),
            const Divider(),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  'Due date: ${FormatHelper.formatDisplayDate(debt.dueDate!)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ],

          // Ghi chú (nếu có)
          if (debt.note != null && debt.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    debt.note!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Cell số tiền nhỏ trong card
  Widget _buildAmountCell(String label, String amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(amount,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
        height: 36, width: 1, color: Colors.grey[200]);
  }

  // Nút toggle trạng thái (đánh dấu hoàn thành / chưa hoàn thành)
  Widget _buildToggleStatusButton(DebtProvider provider, bool finished) {
    return OutlinedButton.icon(
      onPressed: provider.isToggling ? null : _toggleStatus,
      icon: provider.isToggling
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(finished ? Icons.undo : Icons.check_circle_outline),
      label: Text(finished
          ? 'Mark as incomplete'
          : 'Mark as completed'),
      style: OutlinedButton.styleFrom(
        foregroundColor: finished ? Colors.orange : Colors.green,
        side: BorderSide(color: finished ? Colors.orange : Colors.green),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // =============================================
  // [8.7] TRANSACTION SUMMARY — removed (now in _DebtTransactionSection)
  // =============================================

  Widget _buildErrorState(String? msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            msg ?? 'Unable to load debt information',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _DebtTransactionSection — Section lịch sử giao dịch dùng API mới
// =============================================================================
// Gọi GET /api/transactions/list?debtId={id}
// Dùng TransactionListResponse (DTO mới) — có dailyGroups sẵn, không cần group thủ công
class _DebtTransactionSection extends StatefulWidget {
  final int debtId;
  final Future<void> Function()? onTransactionChanged;

  const _DebtTransactionSection({
    required this.debtId,
    this.onTransactionChanged,
  });

  @override
  State<_DebtTransactionSection> createState() =>
      _DebtTransactionSectionState();
}

class _DebtTransactionSectionState extends State<_DebtTransactionSection> {
  bool _isLoading = true;
  String? _error;
  TransactionListResponse? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await TransactionService.getTransactionList(
        filters: {'debtId': widget.debtId.toString()},
      );
      if (!mounted) return;
      setState(() {
        if (res.success && res.data != null) {
          _data = res.data;
        } else {
          _error = res.message;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Transaction history',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
              onPressed: _load,
              tooltip: 'Reload',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            ),
          )
        else if (_error != null)
          Center(
            child: Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          )
        else if (_data == null || _data!.dailyGroups.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No related transactions have been made.',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          // Summary card từ DTO
          _buildSummaryCard(),
          const SizedBox(height: 8),

          // Daily groups — đã được server group sẵn
          ..._data!.dailyGroups.map(
            (group) => TransactionDayGroup(
              date: group.date,
              displayDateLabel: group.displayDateLabel,
              transactions: group.transactions,
              netAmount: group.netAmount,
              onTapTransaction: (tx) => _showDetailSheet(tx),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCard() {
    final d = _data!;
    final net = d.netAmount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _summaryRow('Total number of transactions:', '${d.transactionCount}', Colors.white),
          const SizedBox(height: 6),
          _summaryRow('Total income:', FormatHelper.formatVND(d.totalIncome), Colors.green),
          const SizedBox(height: 6),
          _summaryRow('Total expense:', FormatHelper.formatVND(d.totalExpense), Colors.red),
          const Divider(height: 16),
          _summaryRow(
            'Remaining:',
            FormatHelper.formatVND(net),
            net >= 0 ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  void _showDetailSheet(TransactionResponse transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(
        transaction: transaction,
        onEdit: () {
          Navigator.pop(context);
          _openEdit(transaction);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(transaction);
        },
      ),
    );
  }

  Future<void> _openEdit(TransactionResponse transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => TransactionEditScreen(transaction: transaction)),
    );
    if (result == true && mounted) {
      await widget.onTransactionChanged?.call();
      _load(); // Reload transaction list
    }
  }

  void _confirmDelete(TransactionResponse transaction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            const Text('Delete transaction', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this transaction?\nThe debit balance will be recalculated automatically..',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final txProvider =
                  Provider.of<TransactionProvider>(context, listen: false);
              final success =
                  await txProvider.deleteTransaction(context, transaction.id);
              if (!mounted) return;
              if (success) {
                await widget.onTransactionChanged?.call();
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction deleted'),
                      backgroundColor: Color(0xFF4CAF50),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(txProvider.errorMessage ?? 'An error occurred.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

