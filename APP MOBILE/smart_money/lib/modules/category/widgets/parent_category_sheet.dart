// ===========================================================
// [3.4] Widget: Bottom Sheet chọn danh mục cha
// ===========================================================
// Hiện khi: User bấm "Chọn nhóm cha" trong màn hình tạo/sửa
// API: GET /api/categories/parents?type=false (hoặc true)
// Trả về: danh sách danh mục CHA phù hợp để làm parent

import 'package:flutter/material.dart';
import 'package:smart_money/modules/category/models/category_response.dart';

class ParentCategorySheet extends StatelessWidget {
  // Danh sách danh mục cha để chọn
  final List<CategoryResponse> parents;

  // Danh mục cha đang chọn (highlight)
  final int? selectedParentId;

  const ParentCategorySheet({
    super.key,
    required this.parents,
    this.selectedParentId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Nền tối, bo tròn phía trên
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ----- Thanh tiêu đề -----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Text(
                  "Chọn nhóm cha",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Nút đóng
                GestureDetector(
                  onTap: () => Navigator.pop(context), // đóng sheet
                  child: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.grey),

          // ----- Option "Không có nhóm cha" (tạo danh mục gốc) -----
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade800,
              child: const Icon(Icons.layers_clear, color: Colors.white, size: 20),
            ),
            title: const Text(
              "Không có nhóm cha",
              style: TextStyle(color: Colors.white),
            ),
            // Highlight nếu đang chọn "không có cha"
            trailing: selectedParentId == null
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => Navigator.pop(context, null), // trả về null = không có cha
          ),

          const Divider(height: 1, color: Colors.grey),

          // ----- Danh sách danh mục cha -----
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: parents.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.grey),
              itemBuilder: (context, index) {
                final parent = parents[index];
                final isSelected = parent.id == selectedParentId;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade800,
                    child: const Icon(Icons.category, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    parent.ctgName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  // Highlight nếu đang chọn cha này
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () => Navigator.pop(context, parent), // trả về parent đã chọn
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

