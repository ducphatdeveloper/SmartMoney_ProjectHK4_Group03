// ===========================================================
// [3.2] Widget: Một nhóm danh mục (cha + danh sách con)
// ===========================================================
// Hiện 1 card chứa:
//   • Danh mục cha (ListTile: icon + tên + chevron)
//   • Danh sách con (thụt lề 32px, có thanh dọc xám bên trái)
// Khi bấm vào cha hoặc con → gọi callback onTapCategory

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_money/modules/category/models/category_response.dart';

class CategoryGroupCard extends StatelessWidget {
  // Danh mục cha
  final CategoryResponse parent;

  // Danh sách danh mục con (đã lọc sẵn từ screen)
  final List<CategoryResponse> children;

  // Callback khi bấm vào bất kỳ danh mục nào
  final void Function(CategoryResponse category) onTapCategory;

  const CategoryGroupCard({
    super.key,
    required this.parent,
    required this.children,
    required this.onTapCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E), // card tối
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // ===== [A] DANH MỤC CHA =====
          _buildParentTile(),

          // ===== [B] DANH SÁCH CON (nếu có) =====
          if (children.isNotEmpty)
            ...children.map((child) => _buildChildTile(child)),
        ],
      ),
    );
  }

  // ----- Danh mục cha -----
  Widget _buildParentTile() {
    return ListTile(
      onTap: () => onTapCategory(parent), // bấm → mở edit
      leading: _buildIcon(parent.ctgIconUrl), // icon từ URL hoặc placeholder
      title: Text(
        parent.ctgName,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  // ----- Danh mục con -----
  Widget _buildChildTile(CategoryResponse child) {
    return Row(
      children: [
        // Thanh dọc xám bên trái — thể hiện quan hệ cha-con
        Container(
          width: 32,
          alignment: Alignment.center,
          child: Container(
            width: 2,
            height: 48,
            color: Colors.grey.shade700,
          ),
        ),
        // Item con
        Expanded(
          child: ListTile(
            onTap: () => onTapCategory(child), // bấm → mở edit
            leading: _buildIcon(child.ctgIconUrl),
            title: Text(
              child.ctgName,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  // ----- Build icon: load từ URL, fallback placeholder -----
  Widget _buildIcon(String? iconUrl) {
    // Nếu có URL và là link http → load từ mạng
    if (iconUrl != null && iconUrl.startsWith('http')) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade800,
        child: CachedNetworkImage(
          imageUrl: iconUrl,
          width: 24,
          height: 24,
          placeholder: (_, __) => const Icon(Icons.category, color: Colors.grey, size: 20),
          errorWidget: (_, __, ___) => const Icon(Icons.category, color: Colors.grey, size: 20),
        ),
      );
    }

    // Fallback: icon mặc định khi chưa có URL hoặc là file local (svg)
    return CircleAvatar(
      backgroundColor: Colors.grey.shade800,
      child: const Icon(Icons.category, color: Colors.white, size: 20),
    );
  }
}

