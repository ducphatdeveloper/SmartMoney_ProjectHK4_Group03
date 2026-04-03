// ===========================================================
// [3.1] DebtCardWidget — Hiển thị 1 khoản nợ trong danh sách
// ===========================================================
// Trách nhiệm:
//   • Render thông tin tóm tắt 1 khoản nợ (personName, remain, due date)
//   • Hiển thị thanh tiến trình đã trả/thu (LinearProgressIndicator)
//   • Gọi callback onTap về Screen cha — KHÔNG navigate trực tiếp
//
// Layout:
//   • Row: Avatar chữ cái | Column (tên, note, progress bar) | Column (số tiền)
//   • Nếu finished=true: strikethrough số tiền + icon ✅
//   • Nếu finished=false và dueDate gần → text đỏ cảnh báo
//
// Gọi từ:
//   • DebtListScreen → render từng item trong ListView
// ===========================================================

import 'package:flutter/material.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import '../models/debt_response.dart';

class DebtCardWidget extends StatelessWidget {

  final DebtResponse debt;    // Data khoản nợ cần hiển thị
  final VoidCallback onTap;   // Callback khi user tap → DebtListScreen navigate

  const DebtCardWidget({
    super.key,
    required this.debt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            // Viền đỏ nhạt nếu nợ sắp đến hạn (trong vòng 7 ngày)
            color: _isNearDue
                ? Colors.red.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            // ----- Avatar chữ cái đầu tên -----
            _buildAvatar(context),
            const SizedBox(width: 12),

            // ----- Thông tin chính -----
            Expanded(child: _buildInfo(context)),
            const SizedBox(width: 8),

            // ----- Số tiền còn lại -----
            _buildAmountColumn(context),
          ],
        ),
      ),
    );
  }

  // --------------- Helper Widgets private ---------------

  /// Avatar tròn hiển thị chữ cái đầu tên người vay/cho vay
  Widget _buildAvatar(BuildContext context) {
    final initial = debt.personName.isNotEmpty
        ? debt.personName[0].toUpperCase()
        : '?';
    // [FIX-6] Màu đồng bộ app: Xanh lá nếu xong, Cam nếu CẦN TRẢ, Xanh dương nếu CẦN THU
    // Không dùng colorScheme.primary (có thể là tím — không đồng bộ với Xám-Xanh-Đen-Trắng)
    final activeColor = debt.debtType ? Colors.blue : Colors.orange;
    return CircleAvatar(
      radius: 22,
      backgroundColor: debt.finished
          ? Colors.green.withValues(alpha: 0.3)
          : activeColor.withValues(alpha: 0.18),
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: debt.finished ? Colors.green : activeColor,
        ),
      ),
    );
  }

  /// Cột giữa: tên người, ghi chú, thanh tiến trình
  Widget _buildInfo(BuildContext context) {
    final activeColor = debt.debtType ? Colors.blue : Colors.orange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tên người vay/cho vay
        Text(
          debt.personName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        // Ghi chú (nếu có)
        if (debt.note != null && debt.note!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            debt.note!,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 6),

        // Thanh tiến trình đã trả/thu
        // [FIX] Tăng chiều cao thanh tiến trình lên chút: dễ nhìn hơn trên tab Cần Trả / Cần Thu
        LinearProgressIndicator(
          value: debt.progress,
          backgroundColor: Colors.grey[200],
          // Màu progress bar: xanh lá nếu xong, cam/xanh nếu chưa
          color: debt.finished ? Colors.green : activeColor,
          minHeight: 6, // tăng từ 4 -> 6 (nhỏ nhưng rõ rệt)
          borderRadius: BorderRadius.circular(3),
        ),

        const SizedBox(height: 4),

        // Dòng "Đã trả X / Còn Y" hoặc ngày hẹn trả nếu còn nợ
        if (!debt.finished && debt.dueDate != null)
          Text(
            'Hạn: ${FormatHelper.formatDisplayDate(debt.dueDate!)}',
            style: TextStyle(
              fontSize: 11,
              // Đỏ nếu gần đến hạn, xám nếu còn lâu
              color: _isNearDue ? Colors.red[700] : Colors.grey[500],
            ),
          ),
      ],
    );
  }

  /// Cột phải: số tiền còn lại
  Widget _buildAmountColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (debt.finished)
          // Đã hoàn thành → strikethrough + ✅
          Text(
            FormatHelper.formatVND(debt.totalAmount),
            style: const TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Colors.grey,
              fontSize: 13,
            ),
          )
        else
          // Chưa xong → hiện số tiền còn lại (màu đỏ cho Cần Trả, xanh cho Cần Thu)
          Text(
            FormatHelper.formatVND(debt.remainAmount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              // Cần Trả (false) = đỏ vì mình đang nợ, Cần Thu (true) = xanh
              color: debt.debtType ? Colors.blue[600] : Colors.red[600],
            ),
          ),

        const SizedBox(height: 4),

        if (debt.finished)
          // Label nhỏ xác nhận đã xong
          Text(
            debt.debtType ? 'Đã nhận hết' : 'Đã trả hết',
            style: const TextStyle(fontSize: 11, color: Colors.green),
          )
        else
          // Hiện tổng số để biết context
          Text(
            '/${FormatHelper.formatShort(debt.totalAmount)}',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
      ],
    );
  }

  // --------------- Computed Properties ---------------

  /// true nếu hạn trả còn dưới 7 ngày và chưa hoàn thành
  bool get _isNearDue {
    if (debt.finished || debt.dueDate == null) return false;
    final daysLeft = debt.dueDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 7;
  }
}
