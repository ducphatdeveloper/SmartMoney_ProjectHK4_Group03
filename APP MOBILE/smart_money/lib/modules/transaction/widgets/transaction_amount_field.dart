// ===========================================================
// [3.3] TransactionAmountField — Widget hiển thị số tiền
// ===========================================================
// Dùng ở: TransactionCreateScreen, TransactionEditScreen
// Hiển thị: Badge "VND" bên trái + số tiền to ở giữa
// Màu số: đỏ khi Chi (expense), xanh lá khi Thu (income), trắng khi Vay (debt)
// [NOTE] Không dùng TextField — chỉ hiển thị Text, bàn phím do Screen quản lý
// Tham số:
//   • amount: số tiền dạng string (VD: "150000")
//   • transactionType: 'expense' | 'income' | 'debt' — quyết định màu hiển thị
// ===========================================================

import 'package:flutter/material.dart';
import 'package:smart_money/core/helpers/format_helper.dart';

class TransactionAmountField extends StatelessWidget {

  final String amount;          // số tiền dạng string từ bàn phím tính toán
  final String transactionType; // 'expense' | 'income' | 'debt' — quyết định màu

  const TransactionAmountField({
    super.key,
    required this.amount,
    required this.transactionType,
  });

  @override
  Widget build(BuildContext context) {
    // Xác định màu hiển thị theo loại giao dịch
    final color = _getAmountColor();

    // Parse amount string → double để format
    final amountValue = double.tryParse(amount) ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // Badge "VND" bên trái
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'VND',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Số tiền to ở giữa — format bằng FormatHelper
          Expanded(
            child: Text(
              amountValue > 0
                  ? FormatHelper.formatNumber(amountValue) // VD: "150.000"
                  : '0',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----- Helper: Xác định màu theo loại giao dịch -----
  Color _getAmountColor() {
    switch (transactionType) {
      case 'income':
        return const Color(0xFF4CAF50); // xanh lá — Thu nhập
      case 'debt':
        return Colors.white;             // trắng — Vay/Nợ
      case 'expense':
      default:
        return const Color(0xFFF44336); // đỏ — Chi tiêu
    }
  }
}

