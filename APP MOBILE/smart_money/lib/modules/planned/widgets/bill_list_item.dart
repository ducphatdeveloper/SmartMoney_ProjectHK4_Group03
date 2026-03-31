// ===========================================================
// [3.2] BillListItem — Widget hiển thị 1 hóa đơn
// ===========================================================
// Dùng ở: BillScreen → ListView.builder (cả tab active + expired)
// Tham số:
//   • item: PlannedTransactionResponse — dữ liệu hóa đơn
//   • isExpired: true = tab ĐÃ KẾT THÚC, false = tab ĐANG ÁP DỤNG
//   • onTap: callback khi tap item → Screen cha mở BillDetailSheet
//   • onPay: callback khi bấm "Trả tiền" → Screen cha gọi provider.payBill()
//
// [v2] Đã migrate:
//   • isPaidThisCycle  → displayStatus == "PAID"
//   • daysUntilDue     → tính local từ nextDueDate (backend bỏ field này)
//                        OVERDUE case dùng statusLabel từ backend
// ===========================================================

import 'package:flutter/material.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/planned/models/planned_transaction_response.dart';

class BillListItem extends StatelessWidget {

  final PlannedTransactionResponse item; // dữ liệu hóa đơn
  final bool isExpired;                  // true = tab ĐÃ KẾT THÚC
  final VoidCallback? onTap;             // callback tap item → mở detail sheet
  final VoidCallback? onPay;             // callback trả tiền → gọi provider.payBill()

  const BillListItem({
    super.key,
    required this.item,
    this.isExpired = false,
    this.onTap,
    this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    // categoryType: false = chi (đỏ), true = thu (xanh)
    final isIncome = item.categoryType == true;
    final amountColor = isIncome
        ? const Color(0xFF4CAF50)   // thu → xanh
        : const Color(0xFFFF6B6B);  // chi → đỏ

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Icon category tròn 44px ──
              IconHelper.buildCircleAvatar(
                iconUrl: item.categoryIcon,
                radius: 22,
              ),
              const SizedBox(width: 12),

              // ── Nội dung chính ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Hàng 1: Tên category + Số tiền
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.categoryName ?? 'Không rõ',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Chỉ hiện số tiền ở tab ĐANG ÁP DỤNG
                        if (!isExpired)
                          Text(
                            FormatHelper.formatVND(item.amount),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: amountColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Hàng 2: Tên ví (nhỏ, xám)
                    if (item.walletName != null && !isExpired)
                      Text(
                        item.walletName!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),

                    // Hiển thị khác nhau cho active vs expired
                    if (isExpired) ...[
                      // Tab ĐÃ KẾT THÚC: "Đã kết thúc"
                      const SizedBox(height: 4),
                      const Text(
                        'Đã kết thúc',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ] else ...[
                      // Tab ĐANG ÁP DỤNG: repeatDescription + next due + status + nút trả tiền

                      if (item.repeatDescription != null &&
                          item.repeatDescription!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.repeatDescription!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],

                      // Hóa đơn tiếp theo — ưu tiên nextDueDateLabel từ Backend
                      if (item.nextDueDateLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Hóa đơn tiếp theo: ${item.nextDueDateLabel}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ] else if (item.nextDueDate != null) ...[
                        // Fallback: tự format nếu Backend chưa trả label
                        const SizedBox(height: 4),
                        Text(
                          'Hóa đơn tiếp theo: ${FormatHelper.formatDisplayDate(item.nextDueDate!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],

                      // Số lần lặp lại còn lại (chỉ khi lặp theo COUNT)
                      if (item.remainingCount != null && item.repeatType == 3) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Còn ${item.remainingCount} lần lặp lại',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],

                      // ── Label trạng thái hạn (emoji + màu) ──
                      // [v2] Không còn daysUntilDue từ backend
                      //      → OVERDUE dùng statusLabel, ACTIVE tính local từ nextDueDate
                      _buildDaysUntilDueLabel(),

                      const SizedBox(height: 8),

                      // ── Nút "Trả tiền" / "Đã trả" ──
                      // [v2] isPaidThisCycle → displayStatus == "PAID"
                      _buildPaymentButton(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================
  // Helper: Label trạng thái hạn (emoji + màu)
  // =============================================
  // [v2] Logic:
  //   • displayStatus == "OVERDUE" → dùng statusLabel từ backend ("Quá hạn X ngày")
  //   • displayStatus == "ACTIVE"  → tính ngày còn lại từ nextDueDate local
  //   • displayStatus == "INACTIVE"/"EXPIRED" → hiện xám
  //   • displayStatus == "PAID"    → không hiện (đã có badge "Đã trả" ở nút)
  Widget _buildDaysUntilDueLabel() {

    // ── Helper nội bộ: map số ngày → label + màu ──
    // Giữ nguyên emoji dots và màu như thiết kế cũ
    ({String label, Color color, FontWeight weight}) _resolve(int days) {
      if (days < 0) {
        return (
        label: '🔴 Quá hạn ${days.abs()} ngày',
        color: const Color(0xFFFF3B30),
        weight: FontWeight.w600,
        );
      } else if (days == 0) {
        return (
        label: '🟠 Đến hạn hôm nay',
        color: const Color(0xFFFF9500),
        weight: FontWeight.w600,
        );
      } else if (days <= 3) {
        return (
        label: '🟠 Còn $days ngày',
        color: const Color(0xFFFF9500),
        weight: FontWeight.w600,
        );
      } else if (days <= 7) {
        return (
        label: '🟡 Còn $days ngày',
        color: const Color(0xFFFFCC00),
        weight: FontWeight.w500,
        );
      } else {
        return (
        label: '🟢 Còn $days ngày',
        color: const Color(0xFF4CAF50),
        weight: FontWeight.normal,
        );
      }
    }

    final status = item.displayStatus;

    // [v2] OVERDUE — dùng statusLabel backend tính sẵn, giữ màu đỏ emoji 🔴
    if (status == 'OVERDUE') {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '🔴 ${item.statusLabel ?? "Quá hạn"}',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFFFF3B30),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // INACTIVE — tạm dừng
    if (status == 'INACTIVE') {
      return const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Text(
          '⚫ Đã tạm dừng',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF8E8E93),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // EXPIRED — hết hạn, dùng statusLabel backend
    if (status == 'EXPIRED') {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '⚫ ${item.statusLabel ?? "Đã hết hạn"}',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF8E8E93),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // PAID — không cần hiện thêm label (nút "Đã trả" đã đủ)
    if (status == 'PAID') return const SizedBox.shrink();

    // ACTIVE (hoặc null) — tính ngày còn lại từ nextDueDate local
    // [v2] Backend không còn trả daysUntilDue → tự tính
    if (item.nextDueDate != null) {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final dueDate = DateTime(
        item.nextDueDate!.year,
        item.nextDueDate!.month,
        item.nextDueDate!.day,
      );
      final days = dueDate.difference(todayDate).inDays;
      final r = _resolve(days);
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          r.label,
          style: TextStyle(
            fontSize: 12,
            color: r.color,
            fontWeight: r.weight,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // =============================================
  // Helper: Nút "Trả tiền" / "Đã trả" trên list item
  // =============================================
  // [v2] isPaidThisCycle → displayStatus == "PAID"
  //   • displayStatus == "PAID"  → badge "Đã trả ✓" (disabled, xám)
  //   • else                     → nút "Trả [số tiền]" (xanh, active)
  Widget _buildPaymentButton() {
    // [v2] Dùng displayStatus thay cho isPaidThisCycle
    if (item.displayStatus == 'PAID') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3C),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Color(0xFF8E8E93), size: 18),
                SizedBox(width: 4),
                Text(
                  'Đã trả',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Chưa trả kỳ này → nút xanh active
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: onPay,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.payment, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Trả ${FormatHelper.formatVND(item.amount)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}