// ===========================================================
// [3.3] Widget: Nội dung 1 tab danh mục (Chi / Thu / Vay-Nợ)
// ===========================================================
// Được dùng trong TabBarView — mỗi tab là 1 CategoryTabContent
// Trách nhiệm:
//   • Hiện nút "Nhóm mới" (nếu không phải tab Vay/Nợ)
//   • Hiện danh sách danh mục cha + con theo nhóm
//   • Hiện loading, empty state, error
//
// Logic nhóm cha-con:
//   Danh mục có parentId == null → là CHA
//   Danh mục có parentId != null → là CON (gộp vào dưới cha tương ứng)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/modules/category/providers/category_provider.dart';
import 'package:smart_money/modules/category/widgets/add_category_button.dart';
import 'package:smart_money/modules/category/widgets/category_group_card.dart';

class CategoryTabContent extends StatelessWidget {
  // Tên nhóm: "expense" | "income" | "debt"
  final String group;

  // Callback khi bấm "Nhóm mới"
  final VoidCallback? onAddNew;

  // Callback khi bấm vào 1 danh mục (cha hoặc con)
  final void Function(CategoryResponse category) onTapCategory;

  const CategoryTabContent({
    super.key,
    required this.group,
    this.onAddNew,
    required this.onTapCategory,
  });

  @override
  Widget build(BuildContext context) {
    // Lấy provider để đọc state
    final provider = Provider.of<CategoryProvider>(context);

    // ----- [A] Đang loading → hiện vòng xoay -----
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    // ----- [B] Lỗi → hiện thông báo -----
    if (provider.errorMessage != null) {
      return Center(
        child: Text(
          provider.errorMessage!,
          style: const TextStyle(color: Colors.red, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }

    // ----- [C] Tách danh mục cha và con -----
    final allCategories = provider.categories;

    // Lọc danh mục cha: parentId == null
    final parents = allCategories
        .where((c) => c.parentId == null)
        .toList();

    // Lọc danh mục con: parentId != null
    final childrenMap = <int, List<CategoryResponse>>{}; // key = parentId
    for (var c in allCategories) {
      if (c.parentId != null) {
        childrenMap.putIfAbsent(c.parentId!, () => []);
        childrenMap[c.parentId!]!.add(c);
      }
    }

    // ----- [D] Danh sách rỗng → hiện empty -----
    if (parents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, color: Colors.grey, size: 48),
            SizedBox(height: 12),
            Text(
              "Chưa có danh mục nào",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // ----- [E] Hiện danh sách -----
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Nút "Nhóm mới" — chỉ hiện ở tab Chi và Thu, không hiện ở Vay/Nợ
        if (group != 'debt' && onAddNew != null) ...[
          AddCategoryButton(onTap: onAddNew!),
          const SizedBox(height: 16),
        ],

        // Từng nhóm danh mục cha + con
        for (var parent in parents)
          CategoryGroupCard(
            parent: parent,
            children: childrenMap[parent.id] ?? [], // con thuộc cha này
            onTapCategory: onTapCategory,
          ),

        const SizedBox(height: 16),

        // Nút "Hiển thị nhóm không hoạt động" — TODO: chưa có API cho phần này
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            children: [
              Icon(Icons.visibility, color: Colors.green),
              SizedBox(width: 8),
              Text(
                "Hiển thị nhóm không hoạt động",
                style: TextStyle(color: Colors.green),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

