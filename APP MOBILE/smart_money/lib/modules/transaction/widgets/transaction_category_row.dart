// ===========================================================
// [3.4] TransactionCategoryRow — Widget hiển thị dòng chọn nhóm danh mục
// ===========================================================
// Dùng ở: TransactionCreateScreen, TransactionEditScreen
// Hiển thị: CircleAvatar icon + tên danh mục (hoặc "Chọn nhóm" nếu chưa chọn)
// Tham số:
//   • selected: CategoryResponse đã chọn (null = chưa chọn)
//   • onTap: callback khi user bấm → Screen cha navigate sang CategoryListScreen
// ===========================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';

class TransactionCategoryRow extends StatelessWidget {

  final CategoryResponse? selected;  // danh mục đã chọn (null = chưa chọn)
  final VoidCallback onTap;          // callback khi bấm → Screen cha navigate

  const TransactionCategoryRow({
    super.key,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // [FIX-LAG] opaque: toàn bộ vùng row (kể cả padding transparent) nhận hit
      // Không có behavior này, vùng padding trong suốt sẽ xuyên qua xuống body GestureDetector
      // gây ra setState rebuild → bottomSheet / Navigator.push không kịp fire → phải click 2-3 lần
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon danh mục hoặc placeholder xám
            _buildIcon(),
            const SizedBox(width: 12),

            // Tên danh mục hoặc "Chọn nhóm"
            Expanded(
              child: Text(
                selected?.ctgName ?? 'Chọn nhóm', // hiện tên nếu đã chọn
                style: TextStyle(
                  color: selected != null ? Colors.white : Colors.grey,
                  fontSize: 16,
                  fontWeight: selected != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),

            // Mũi tên phải
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ----- Helper: Build icon danh mục -----
  Widget _buildIcon() {
    if (selected != null && selected!.ctgIconUrl != null && selected!.ctgIconUrl!.isNotEmpty) {
      // Đã chọn + có icon → build Cloudinary URL và load từ network
      final categoryUrl = IconHelper.buildCloudinaryUrl(selected!.ctgIconUrl);
      
      if (categoryUrl != null && categoryUrl.isNotEmpty) {
        return CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey[800],
          child: CachedNetworkImage(
            imageUrl: categoryUrl,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            placeholder: (_, __) => const Icon(Icons.category, color: Colors.grey, size: 20),
            errorWidget: (_, __, ___) => const Icon(Icons.category, color: Colors.grey, size: 20),
          ),
        );
      }
    }

    // Chưa chọn hoặc không có icon → placeholder xám
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey[800],
      child: Icon(
        selected != null ? Icons.category : Icons.help_outline,
        color: Colors.grey,
        size: 20,
      ),
    );
  }
}

