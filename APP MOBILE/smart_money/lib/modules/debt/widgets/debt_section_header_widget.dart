// ===========================================================
// [3.2] DebtSectionHeaderWidget — Header phân chia section trong list
// ===========================================================
// Trách nhiệm:
//   • Hiển thị label section và tổng số tiền (VD: "CHƯA TRẢ 4,950,000đ")
//   • Dùng cho cả 4 section: CHƯA TRẢ, ĐÃ TRẢ HẾT, CHƯA THU, ĐÃ NHẬN HẾT
//
// Layout:
//   • Row: Đường kẻ | Text label | Số tiền | Đường kẻ
//
// Gọi từ:
//   • DebtListScreen → render trước mỗi nhóm trong ListView
// ===========================================================

import 'package:flutter/material.dart';
import 'package:smart_money/core/helpers/format_helper.dart';

class DebtSectionHeaderWidget extends StatelessWidget {

  final String label;      // VD: "CHƯA TRẢ" / "ĐÃ TRẢ HẾT"
  final double totalAmount;// Tổng số tiền trong section này
  final Color color;       // Màu số tiền (đỏ/xanh/xám)

  const DebtSectionHeaderWidget({
    super.key,
    required this.label,
    required this.totalAmount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          // Đường kẻ trái
          Expanded(child: Divider(color: Colors.grey[300])),
          const SizedBox(width: 8),

          // Label section
          Text(
            '$label  ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.8,
            ),
          ),

          // Số tiền nổi bật
          Text(
            FormatHelper.formatVND(totalAmount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),

          const SizedBox(width: 8),
          // Đường kẻ phải
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }
}
