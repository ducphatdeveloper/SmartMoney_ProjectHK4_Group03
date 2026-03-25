// ===========================================================
// [3.4] Widget: Bottom Sheet chọn danh mục cha
// ===========================================================
// Hiện khi: User bấm "Chọn nhóm cha" trong màn hình tạo/sửa
// API: GET /api/categories/parents?type=false (hoặc true)
// Trả về: danh sách danh mục CHA phù hợp để làm parent
// [FIX-3] Bổ sung ô tìm kiếm theo tên

import 'package:flutter/material.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';

class ParentCategorySheet extends StatefulWidget {
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
  State<ParentCategorySheet> createState() => _ParentCategorySheetState();
}

class _ParentCategorySheetState extends State<ParentCategorySheet> {
  // Controller ô tìm kiếm
  final _searchController = TextEditingController();
  // Danh sách đã lọc theo từ khóa
  List<CategoryResponse> _filteredParents = [];

  @override
  void initState() {
    super.initState();
    _filteredParents = widget.parents; // ban đầu hiện tất cả
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Lọc danh sách khi user gõ tìm kiếm
  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredParents = widget.parents;
      } else {
        _filteredParents = widget.parents
            .where((p) => p.ctgName.toLowerCase().contains(query))
            .toList();
      }
    });
  }

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

          // ----- Ô tìm kiếm -----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Tìm kiếm nhóm cha...",
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                // Nút xóa ô tìm kiếm
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: const Icon(Icons.clear, color: Colors.grey, size: 18),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade900,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),
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
            trailing: widget.selectedParentId == null
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => Navigator.pop(context, null), // trả về null = không có cha
          ),

          const Divider(height: 1, color: Colors.grey),

          // ----- Danh sách danh mục cha (đã lọc) -----
          Flexible(
            child: _filteredParents.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Không tìm thấy nhóm cha",
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _filteredParents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.grey),
                    itemBuilder: (context, index) {
                      final parent = _filteredParents[index];
                      final isSelected = parent.id == widget.selectedParentId;

                      return ListTile(
                        leading: IconHelper.buildCircleAvatar(
                          iconUrl: parent.ctgIconUrl,
                          radius: 20,
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

