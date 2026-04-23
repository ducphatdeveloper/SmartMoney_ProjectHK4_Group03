// ===========================================================
// [5] Màn hình 2: Tạo Danh mục mới (CategoryCreateScreen)
// ===========================================================
// Layout:
//   • AppBar: "Nhóm mới" + nút back
//   • Row 1: Icon (chọn icon) + TextField tên nhóm
//   • Row 2: Radio chọn Khoản chi / Khoản thu
//   • Row 3: Chọn nhóm cha → mở BottomSheet
//   • Button "Lưu" cố định cuối màn hình
//
// Flow:
//   1. User nhập tên + chọn loại (chi/thu)
//   2. (Tùy chọn) Chọn nhóm cha từ BottomSheet
//   3. Bấm "Lưu" → gọi POST /api/categories
//   4. Thành công → pop về CategoryListScreen với result=true
//   5. Thất bại → hiện SnackBar lỗi từ server (tiếng Việt)
//
// Validation:
//   • Tên không được trống (server kiểm tra @NotBlank)
//   • Tên tối đa 100 ký tự (server kiểm tra @Size)
//   • Trùng tên → server trả message cụ thể
// ===========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_money/modules/category/providers/category_provider.dart';
import 'package:smart_money/modules/category/models/category_request.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/modules/category/models/icon_dto.dart';
import 'package:smart_money/modules/category/widgets/parent_category_sheet.dart';
import 'package:smart_money/modules/category/screens/icon_picker_screen.dart';

class CategoryCreateScreen extends StatefulWidget {
  // Loại mặc định khi mở từ tab Chi (false) hoặc Thu (true)
  final bool defaultCtgType;

  const CategoryCreateScreen({super.key, required this.defaultCtgType});

  @override
  State<CategoryCreateScreen> createState() => _CategoryCreateScreenState();
}

class _CategoryCreateScreenState extends State<CategoryCreateScreen> {

  // =============================================
  // [5.1] STATE — Dữ liệu form
  // =============================================

  // Controller cho TextField tên danh mục
  final _nameController = TextEditingController();

  // Loại danh mục: true = Thu nhập, false = Chi tiêu
  late bool _ctgType;

  // Danh mục cha đã chọn (null = tạo danh mục gốc)
  CategoryResponse? _selectedParent;

  // Icon đã chọn từ IconPickerScreen (null = dùng mặc định)
  IconDto? _selectedIcon;

  // Đang gửi request (disable nút Lưu khi đang gọi API)
  bool _isSaving = false;

  // =============================================
  // [5.2] initState — gán giá trị mặc định
  // =============================================
  @override
  void initState() {
    super.initState();
    _ctgType = widget.defaultCtgType; // lấy từ tab đang chọn
  }

  // =============================================
  // [5.3] dispose — giải phóng controller
  // =============================================
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // =============================================
  // [5.4] _openParentSheet — mở BottomSheet chọn nhóm cha
  // =============================================
  void _openParentSheet() async {
    // Bước 1: Load danh sách cha từ API trước khi mở sheet
    final provider = Provider.of<CategoryProvider>(context, listen: false);
    await provider.loadParents(context, _ctgType); // GET /api/categories/parents?type=false

    if (!mounted) return;

    // Bước 2: Mở BottomSheet
    final result = await showModalBottomSheet<CategoryResponse?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // cho phép sheet cao hơn nửa màn hình
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        builder: (_, scrollController) => ParentCategorySheet(
          parents: provider.parentCategories,
          selectedParentId: _selectedParent?.id,
        ),
      ),
    );

    // Bước 3: Cập nhật kết quả chọn
    // result == null nghĩa là chọn "Không có nhóm cha"
    // Nếu user bấm nút đóng (X) thì result cũng null → giữ nguyên
    setState(() {
      _selectedParent = result;
    });
  }

  // =============================================
  // [5.4b] _openIconPicker — mở màn hình chọn icon
  // =============================================
  void _openIconPicker() async {
    final result = await Navigator.push<IconDto>(
      context,
      MaterialPageRoute(
        builder: (_) => IconPickerScreen(
          currentIconFileName: _selectedIcon?.fileName,
        ),
      ),
    );

    // Nếu user chọn icon → cập nhật state
    if (result != null && mounted) {
      setState(() {
        _selectedIcon = result;
      });
    }
  }

  // =============================================
  // [5.5] _saveCategory — gọi API tạo danh mục
  // =============================================
  void _saveCategory() async {
    // Bước 1: Validate tên không trống (client-side)
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter category name"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Bước 2: Tạo request body
    final request = CategoryRequest(
      ctgName: name,
      ctgType: _ctgType,
      ctgIconUrl: _selectedIcon?.fileName, // fileName từ icon picker (null = mặc định)
      parentId: _selectedParent?.id, // null nếu tạo danh mục gốc
    );

    // Bước 3: Gọi API qua provider
    setState(() => _isSaving = true);

    final provider = Provider.of<CategoryProvider>(context, listen: false);
    final success = await provider.createCategory(context, request);

    setState(() => _isSaving = false);

    if (!mounted) return;

    // Bước 4: Xử lý kết quả
    if (success) {
      // Thành công → hiện thông báo + quay về
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.successMessage ?? "Category created successfully"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // trả result=true để list reload
    } else {
      // Thất bại → hiện lỗi từ server (tiếng Việt)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? "An error occurred"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =============================================
  // [5.6] build — giao diện form tạo mới
  // =============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("New category"),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== [A] Row 1: Icon + Tên nhóm =====
            Row(
              children: [
                // Icon danh mục (bấm để chọn icon từ server)
                GestureDetector(
                  onTap: _openIconPicker,
                  child: _selectedIcon != null
                      ? CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade800,
                          child: CachedNetworkImage(
                            imageUrl: _selectedIcon!.url,
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Icon(Icons.category, color: Colors.white, size: 24),
                            errorWidget: (_, __, ___) => const Icon(Icons.category, color: Colors.white, size: 24),
                          ),
                        )
                      : CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade800,
                          child: const Icon(Icons.category, color: Colors.white, size: 24),
                        ),
                ),
                const SizedBox(width: 16),
                // TextField nhập tên
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLength: 100, // tối đa 100 ký tự (khớp backend @Size)
                    decoration: const InputDecoration(
                      hintText: "Category name",
                      hintStyle: TextStyle(color: Colors.grey),
                      counterStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ===== [B] Row 2: Chọn loại (Chi / Thu) =====
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.grey),
                  const SizedBox(width: 12),
                  // Chọn: Khoản chi
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _ctgType = false;
                          _selectedParent = null; // reset cha khi đổi loại
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            _ctgType == false ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: _ctgType == false ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text("Expense",
                              style: TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  // Chọn: Khoản thu
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _ctgType = true;
                          _selectedParent = null; // reset cha khi đổi loại
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            _ctgType == true ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: _ctgType == true ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text("Income",
                              style: TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ===== [C] Row 3: Chọn nhóm cha =====
            GestureDetector(
              onTap: _openParentSheet, // mở BottomSheet
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        // Hiện tên cha đã chọn hoặc placeholder
                        _selectedParent?.ctgName ?? "Select parent category",
                        style: TextStyle(
                          color: _selectedParent != null ? Colors.white : Colors.grey,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // ===== [D] Button "Lưu" =====
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveCategory, // disable khi đang lưu
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        "Save",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

