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
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';
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
      context.read<DebtProvider>().loadDetail(widget.debtId);
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
      await provider.loadDetail(widget.debtId);
    }
  }

  // Dialog xác nhận xóa
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa khoản nợ?'),
        content: const Text(
          'Khoản nợ sẽ bị xóa. '
          'Các giao dịch liên quan sẽ KHÔNG bị xóa theo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Bước: Gọi provider.deleteDebt → pop về list
    final success = await context
        .read<DebtProvider>()
        .deleteDebt(widget.debtId, widget.debtType);

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
        .toggleStatus(widget.debtId);

    if (!mounted) return;
    if (success) {
      _hasChanges = true; // Báo list phải reload
    } else {
      _showError(context.read<DebtProvider>().errorMessage);
    }
  }

  // [NOTE] Thêm giao dịch trả/thu nợ → navigate sang TransactionCreateScreen
  // Truyền debtId + categoryId phù hợp để pre-fill form
  void _openAddTransaction() {
    // widget.debtType=false (CẦN TRẢ) → categoryId=22 (Trả nợ)
    // widget.debtType=true  (CẦN THU) → categoryId=21 (Thu nợ)
    final categoryId = widget.debtType ? 21 : 22;

    // [TODO] Navigate đến TransactionCreateScreen với args:
    //   debtId: widget.debtId, preselectedCategoryId: categoryId
    // Khi module Transaction đã sẵn sàng nhận params này
    // Tạm thời hiện SnackBar hướng dẫn
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tạo giao dịch "${widget.debtType ? 'Thu nợ' : 'Trả nợ'}" '
          'và chọn khoản nợ này để cập nhật số dư.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showError(String? msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg ?? 'Đã xảy ra lỗi'),
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
              title: Text(debt?.personName ?? 'Chi tiết nợ'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context, _hasChanges),
              ),
              actions: [
                // Nút sửa — chỉ hiện khi đã load xong
                if (debt != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Sửa thông tin',
                    onPressed: provider.isSaving ? null : _openEdit,
                  ),
                // Nút xóa
                if (debt != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Xóa khoản nợ',
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
                  ? 'THÊM GIAO DỊCH THU NỢ'
                  : 'THÊM GIAO DỊCH TRẢ NỢ',
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
        const Text(
          'Lịch sử giao dịch',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),

        if (provider.debtTransactions.isEmpty)
          // Chưa có giao dịch nào (không nên xảy ra vì debt luôn có ít nhất 1 giao dịch gốc)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Chưa có giao dịch liên quan',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          )
        else
          // Danh sách giao dịch
          ...provider.debtTransactions.map(
            (tx) => _buildTransactionItem(tx),
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
            color: Colors.black.withOpacity(0.06),
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
              _buildAmountCell('Tổng nợ',
                  FormatHelper.formatVND(debt.totalAmount), Colors.grey[700]!),
              _buildDivider(),
              _buildAmountCell(
                  widget.debtType ? 'Đã thu' : 'Đã trả',
                  FormatHelper.formatVND(debt.paidAmount),
                  Colors.green[600]!),
              _buildDivider(),
              _buildAmountCell(
                  'Còn lại',
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
                '${(debt.progress * 100).toStringAsFixed(0)}% hoàn thành',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (debt.finished)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '✅ Hoàn thành',
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
                  'Hạn trả: ${FormatHelper.formatDisplayDate(debt.dueDate!)}',
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
          ? 'Đánh dấu chưa hoàn thành'
          : 'Đánh dấu đã hoàn thành'),
      style: OutlinedButton.styleFrom(
        foregroundColor: finished ? Colors.orange : Colors.green,
        side: BorderSide(color: finished ? Colors.orange : Colors.green),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Item giao dịch trong lịch sử
  Widget _buildTransactionItem(TransactionResponse tx) {
    // Phân biệt giao dịch gốc (Cho vay/Đi vay) và giao dịch trả/thu
    final isOrigin = [19, 20].contains(tx.categoryId); // categoryId Cho vay/Đi vay
    final isPositive = [19, 21].contains(tx.categoryId); // Thu tiền về ví

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Icon danh mục
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isOrigin
                  ? Colors.orange.withOpacity(0.15)
                  : Colors.blue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOrigin ? Icons.swap_horiz : Icons.payment,
              color: isOrigin ? Colors.orange : Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Tên danh mục + ghi chú + ngày
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.categoryName ?? 'Giao dịch',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14),
                ),
                if (tx.note != null && tx.note!.isNotEmpty)
                  Text(
                    tx.note!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  FormatHelper.formatDisplayDate(tx.transDate),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // Số tiền
          Text(
            '${isPositive ? '+' : '-'}${FormatHelper.formatVND(tx.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isPositive ? Colors.blue[600] : Colors.red[600],
            ),
          ),
        ],
      ),
    );
  }

  // Error state khi không load được
  Widget _buildErrorState(String? msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            msg ?? 'Không thể tải thông tin khoản nợ',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }
}
