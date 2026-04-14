// ===========================================================
// [3.6] TransactionDetailSheet — BottomSheet xem chi tiết giao dịch
// ===========================================================
// Hiển thị khi user bấm vào 1 giao dịch trong danh sách.
// Layout (dark, bo tròn trên):
//   • Handle bar (thanh kéo nhỏ ở trên cùng)
//   • CircleAvatar icon category (to, radius 32)
//   • Tên category (chữ to, trắng)
//   • Số tiền (to, màu đỏ nếu chi / xanh nếu thu)
//   • Divider
//   • Row: icon lịch + ngày giao dịch
//   • Row: icon ví + tên ví
//   • Row: icon ghi chú + ghi chú (ẩn nếu null)
//   • Row: icon người + "Với: tên" (ẩn nếu null)
//   • 2 nút: [Xóa] đỏ + [Sửa] xanh
//
// Cách mở từ màn cha:
//   showModalBottomSheet(
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     builder: (_) => TransactionDetailSheet(
//       transaction: transaction,
//       onEdit: () { Navigator.pop(context); _navigateToEdit(transaction); },
//       onDelete: () { Navigator.pop(context); _confirmDelete(transaction); },
//     ),
//   )
// ===========================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';

class TransactionDetailSheet extends StatelessWidget {
  final TransactionResponse transaction; // giao dịch cần xem chi tiết
  final VoidCallback onEdit;             // callback khi bấm "Sửa"
  final VoidCallback onDelete;           // callback khi bấm "Xóa"

  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // categoryType: true = Thu (xanh), false = Chi (đỏ)
    final isIncome = transaction.categoryType;
    final amountColor = isIncome ? Colors.green : Colors.red;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E), // nền dark
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ===== Handle bar =====
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ===== Icon category (to, radius 32) =====
          _buildCategoryAvatar(),
          const SizedBox(height: 12),

          // ===== Tên category =====
          Text(
            transaction.categoryName ?? 'Không có danh mục',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // ===== Số tiền =====
          Text(
            '${isIncome ? '+' : '-'}${FormatHelper.formatVND(transaction.amount)}',
            style: TextStyle(
              color: amountColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // ===== Divider =====
          Divider(color: Colors.grey[700], height: 1),
          const SizedBox(height: 12),

          // ===== Row ngày giao dịch =====
          _buildInfoRow(
            icon: Icons.calendar_today,
            label: FormatHelper.formatDisplayDate(transaction.transDate),
          ),

          // ===== Row tên ví =====
          if (transaction.walletName != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Icon ví
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: IconHelper.buildWalletIcon(
                      iconUrl: transaction.walletIconUrl,
                      size: 20,
                      placeholder: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      transaction.walletName!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // ===== Row tên mục tiêu tiết kiệm (nếu là saving goal) =====
          if (transaction.savingGoalName != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Icon saving goal
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: IconHelper.buildSavingGoalIcon(
                      iconUrl: transaction.savingGoalIconUrl,
                      size: 20,
                      placeholder: Icon(
                        Icons.savings_outlined,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      transaction.savingGoalName!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // ===== Row ghi chú (ẩn nếu null) =====
          if (transaction.note != null && transaction.note!.isNotEmpty)
            _buildInfoRow(
              icon: Icons.notes,
              label: transaction.note!,
            ),

          // ===== Row "Với ai" (ẩn nếu null) =====
          if (transaction.withPerson != null && transaction.withPerson!.isNotEmpty)
            _buildInfoRow(
              icon: Icons.person_outline,
              label: 'Với: ${transaction.withPerson}',
            ),

          // ===== Row sự kiện (ẩn nếu null) =====
          if (transaction.eventName != null && transaction.eventName!.isNotEmpty)
            _buildInfoRow(
              icon: Icons.event_outlined,
              label: transaction.eventName!,
            ),

          // ===== Row "Không tính vào báo cáo" =====
          if (!transaction.reportable)
            _buildInfoRow(
              icon: Icons.visibility_off_outlined,
              label: 'Không tính vào báo cáo',
              labelColor: Colors.orange,
            ),


          const SizedBox(height: 20),

          // ===== 2 nút: Xóa + Sửa =====
          Row(
              children: [
                // Nút Xóa (đỏ, outlined)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    label: const Text('Xóa', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Nút Sửa (xanh, filled)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Sửa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // Safe area padding phía dưới (tránh bị che bởi navigation bar)
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  // ===== Widget: Row thông tin chi tiết =====
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    Color? labelColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[500], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: labelColor ?? Colors.white,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ===== Widget: Avatar icon category =====
  Widget _buildCategoryAvatar() {
    final isIncome = transaction.categoryType;

    // Sử dụng IconHelper để display icon từ URL Cloudinary
    final categoryUrl = IconHelper.buildCloudinaryUrl(transaction.categoryIconUrl);
    
    if (categoryUrl != null && categoryUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: categoryUrl,
        width: 64,
        height: 64,
        imageBuilder: (context, imageProvider) {
          return CircleAvatar(
            radius: 32,
            backgroundImage: imageProvider,
          );
        },
        placeholder: (_, __) => _buildFallbackAvatar(isIncome),
        errorWidget: (_, __, ___) => _buildFallbackAvatar(isIncome),
      );
    }

    // Không có URL → fallback
    return _buildFallbackAvatar(isIncome);
  }

  // ===== Widget: Fallback avatar khi không có icon =====
  Widget _buildFallbackAvatar(bool isIncome) {
    return CircleAvatar(
      radius: 32,
      backgroundColor: isIncome
          ? Colors.green.withValues(alpha: 0.2)
          : Colors.red.withValues(alpha: 0.2),
      child: Icon(
        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
        color: isIncome ? Colors.green : Colors.red,
        size: 28,
      ),
    );
  }
}

