// ===========================================================
// [3.1] RecurringListItem — Widget hiển thị 1 giao dịch định kỳ
// ===========================================================
// Dùng ở: RecurringScreen → ListView.builder
// Tham số:
//   • item: PlannedTransactionResponse — dữ liệu giao dịch định kỳ
//   • onTap: callback khi tap item → Screen cha mở RecurringDetailSheet
//
// [v2] Thêm: Hàng trạng thái dùng displayStatus + statusLabel từ backend
//   • "ACTIVE"   → 🟢 + statusLabel ("Lặp lại vô thời hạn" / "Lặp lại đến XX/XX")
//   • "OVERDUE"  → 🔴 + statusLabel ("Quá hạn X ngày")
//   • "INACTIVE" → ⚫ "Đã tạm dừng"
//   • "EXPIRED"  → ⚫ + statusLabel ("Đã hết hạn ngày XX/XX")
// ===========================================================

import 'package:flutter/material.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/planned/models/planned_transaction_response.dart';

class RecurringListItem extends StatelessWidget {

  final PlannedTransactionResponse item; // dữ liệu giao dịch định kỳ
  final VoidCallback? onTap;             // callback tap item → mở detail sheet

  const RecurringListItem({
    super.key,
    required this.item,
    this.onTap,
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
                    if (item.walletName != null)
                      Text(
                        item.walletName!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    const SizedBox(height: 4),

                    // Hàng 3: repeatDescription từ Backend
                    if (item.repeatDescription != null &&
                        item.repeatDescription!.isNotEmpty)
                      Text(
                        item.repeatDescription!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),

                    // Hàng 4: Lần xuất hiện tiếp theo — ưu tiên nextDueDateLabel
                    if (item.nextDueDateLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Lần tới: ${item.nextDueDateLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ] else if (item.nextDueDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Lần tới: ${FormatHelper.formatDisplayDate(item.nextDueDate!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],

                    // [2] Số lần lặp lại còn lại — hiện cho TẤT CẢ repeat_type (ngày/tuần/tháng/năm)
                    // Bug cũ: chỉ hiện khi repeatType == 3 (tháng), thiếu ngày/tuần/năm
                    if (item.remainingCount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Còn ${item.remainingCount} lần lặp lại',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],

                    // Hàng 5: [v2] Badge trạng thái — displayStatus + statusLabel
                    // Emoji dots + màu sắc nhất quán với BillListItem
                    _buildStatusLabel(),

                    // Hàng 6: Chevron gợi ý có thể tap
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.chevron_right,
                          color: Color(0xFF8E8E93), size: 20),
                    ),
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
  // Helper: Badge trạng thái — emoji dots + màu
  // =============================================
  // [v2] Dùng displayStatus để chọn emoji/màu,
  //      dùng statusLabel (backend tính sẵn) làm nội dung text.
  //
  // Mapping:
  //   ACTIVE   → 🟢 statusLabel  ("Lặp lại vô thời hạn" / "Lặp lại đến XX/XX")
  //   OVERDUE  → 🔴 statusLabel  ("Quá hạn X ngày")
  //   INACTIVE → ⚫ "Đã tạm dừng"
  //   EXPIRED  → ⚫ statusLabel  ("Đã hết hạn ngày XX/XX")
  //   null     → SizedBox.shrink()
  Widget _buildStatusLabel() {
    final status = item.displayStatus;
    if (status == null) return const SizedBox.shrink();

    switch (status) {
      case 'ACTIVE':
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '🟢 ${item.statusLabel ?? "Đang hoạt động"}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4CAF50),
              fontWeight: FontWeight.normal,
            ),
          ),
        );

      case 'OVERDUE':
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '🔴 ${item.statusLabel ?? "Quá hạn"}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFFF3B30),
              fontWeight: FontWeight.w600,
            ),
          ),
        );

      case 'INACTIVE':
        return const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            '⚫ Đã tạm dừng',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF8E8E93),
              fontWeight: FontWeight.w500,
            ),
          ),
        );

      case 'EXPIRED':
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '⚫ ${item.statusLabel ?? "Đã hết hạn"}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8E8E93),
              fontWeight: FontWeight.w500,
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}