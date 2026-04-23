// ===========================================================
// [3.1] Widget: Nút "Nhóm mới" — hiện ở đầu tab Chi và Thu
// ===========================================================
// Chỉ hiện ở tab "Khoản chi" và "Khoản thu"
// Không hiện ở tab "Vay/Nợ" (danh mục hệ thống, không cho tạo)
// Khi bấm → navigate sang CategoryCreateScreen

import 'package:flutter/material.dart';

class AddCategoryButton extends StatelessWidget {
  // Callback khi bấm nút
  final VoidCallback onTap;

  const AddCategoryButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // gọi navigate từ screen cha
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E), // nền tối
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.green), // icon +
            SizedBox(width: 8),
            Text(
              "New Category",
              style: TextStyle(color: Colors.green, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

