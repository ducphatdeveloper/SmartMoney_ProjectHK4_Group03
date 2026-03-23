// ===========================================================
// [3.2] TransactionDatePicker — Widget chọn ngày giao dịch
// ===========================================================
// Dùng ở: TransactionCreateScreen, TransactionEditScreen
// Hiển thị: Icon lịch | < | "Thứ Hai, 23/03/2026" | >
// Tham số:
//   • selectedDate: ngày đang chọn
//   • onChanged: callback khi user đổi ngày → Screen cha cập nhật state
// ===========================================================

import 'package:flutter/material.dart';
import 'package:smart_money/core/helpers/format_helper.dart';

class TransactionDatePicker extends StatelessWidget {

  final DateTime selectedDate;             // ngày đang chọn
  final ValueChanged<DateTime> onChanged;  // callback khi user đổi ngày

  const TransactionDatePicker({
    super.key,
    required this.selectedDate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icon lịch bên trái
          const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
          const SizedBox(width: 12),

          // Nút < lùi 1 ngày
          GestureDetector(
            onTap: () {
              // Lùi 1 ngày
              onChanged(selectedDate.subtract(const Duration(days: 1)));
            },
            child: const Icon(Icons.chevron_left, color: Colors.white70, size: 24),
          ),

          // Ngày hiển thị (bấm vào mở DatePicker)
          Expanded(
            child: GestureDetector(
              onTap: () => _showDatePicker(context),
              child: Text(
                // Dùng FormatHelper để format ngày thân thiện
                FormatHelper.formatDisplayDate(selectedDate),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Nút > tiến 1 ngày
          GestureDetector(
            onTap: () {
              // Tiến 1 ngày
              onChanged(selectedDate.add(const Duration(days: 1)));
            },
            child: const Icon(Icons.chevron_right, color: Colors.white70, size: 24),
          ),
        ],
      ),
    );
  }

  // ----- Helper: Mở DatePicker của Flutter -----
  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020, 1, 1),     // cho phép chọn từ 2020
      lastDate: DateTime(2030, 12, 31),     // đến 2030
      // Theme tối cho đồng bộ với app
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4CAF50),     // màu xanh lá cho nút chọn
              surface: Color(0xFF303030),      // nền tối
            ),
          ),
          child: child!,
        );
      },
    );

    // Nếu user chọn ngày → gọi callback về Screen cha
    if (picked != null) {
      onChanged(picked);
    }
  }
}

