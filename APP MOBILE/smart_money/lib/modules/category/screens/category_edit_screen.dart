// ===========================================================
// [6] Màn hình 3: Chỉnh sửa Danh mục (CategoryEditScreen)
// ===========================================================
// Layout:
//   • AppBar: "Chỉnh sửa nhóm" + nút back
//   • Row 1: Icon (chọn icon) + TextField tên nhóm (pre-filled)
//   • Row 2: Radio chọn Khoản chi / Khoản thu (pre-filled)
//   • Row 3: Chọn nhóm cha → mở BottomSheet (hiển thị tên cha hiện tại)
//   • Button "Lưu" + Button "Xóa" cố định cuối màn hình
//
// Flow:
//   1. Pre-fill dữ liệu từ category truyền vào
//   2. (Tùy chọn) Đổi tên, loại, hoặc nhóm cha
//   3. Bấm "Lưu" → gọi PUT /api/categories/{id}
//   4. Bấm "Xóa" → xác nhận → gọi DELETE /api/categories/{id}
//   5. Thành công → pop về list với result=true
//
// Lỗi từ server:
//   • "Bạn không có quyền sửa danh mục này." (403 — danh mục hệ thống)
//   • "Bạn không có quyền xóa danh mục này." (403 — danh mục hệ thống)
//   • "Tên danh mục 'X' đã được sử dụng." (400 — trùng tên)
// Fix:
//   • [FIX-1] Dùng _effectiveParentId thay vì (_selectedParent?.id ?? widget.category.parentId)
//             để tránh gửi parentId cũ khi user đổi loại Chi ↔ Thu
//   • [FIX-2] Hiển thị tên cha thực sự khi mở form (load từ API)
// ===========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/category/providers/category_provider.dart';
import 'package:smart_money/modules/category/models/category_request.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/modules/category/widgets/parent_category_sheet.dart';

class CategoryEditScreen extends StatefulWidget {
  final CategoryResponse category; // danh mục cần sửa

  const CategoryEditScreen({super.key, required this.category});

  @override
  State<CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends State<CategoryEditScreen> {

  // =============================================
  // [6.1] STATE
  // =============================================

  final _nameController = TextEditingController();
  late bool _ctgType; // true = Thu nhập, false = Chi tiêu

  // [FIX-1] Dùng int? _effectiveParentId để track parentId rõ ràng:
  //   - Khởi tạo = widget.category.parentId (giá trị cũ từ server)
  //   - Khi user đổi loại (Chi↔Thu) → set = null (xóa cha)
  //   - Khi user chọn cha mới từ sheet → set = id cha mới
  //   - Khi user chọn "Không có nhóm cha" → set = null
  int? _effectiveParentId;

  // [FIX-2] Tên cha hiển thị trên UI
  String? _parentDisplayName;

  bool _isSaving = false;   // đang gửi request cập nhật — disable nút Lưu
  bool _isDeleting = false; // đang gửi request xóa — disable nút Xóa

  // =============================================
  // [6.2] initState — pre-fill form
  // =============================================
  @override
  void initState() {
    super.initState();

    // Bước 1: Gán tên và loại từ category truyền vào
    _nameController.text = widget.category.ctgName;
    _ctgType = widget.category.ctgType ?? false;

    // Bước 2: [FIX-1] Gán parentId ban đầu từ server
    _effectiveParentId = widget.category.parentId;

    // Bước 3: [FIX-2] Nếu có cha, load tên cha để hiển thị
    if (widget.category.parentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadParentName());
    }
  }

  @override
  void dispose() {
    _nameController.dispose(); // giải phóng controller để tránh memory leak
    super.dispose();
  }

  // =============================================
  // [6.3] _loadParentName — load tên cha hiện tại để hiển thị
  // =============================================
  // Gọi trong initState nếu category đang có cha (parentId != null)
  // Mục đích: hiện đúng tên cha thay vì placeholder "Chọn nhóm cha"
  // API: GET /api/categories/parents?type={ctgType}
  // Lưu ý: firstOrNull trả null nếu cha bị xóa → hiện placeholder
  Future<void> _loadParentName() async {
    final provider = Provider.of<CategoryProvider>(context, listen: false);
    await provider.loadParents(_ctgType); // GET /api/categories/parents?type=...

    if (!mounted) return;

    // Tìm cha trong danh sách theo parentId
    final parent = provider.parentCategories
        .where((p) => p.id == widget.category.parentId)
        .firstOrNull;

    setState(() {
      _parentDisplayName = parent?.ctgName;
    });
  }

  // =============================================
  // [6.4] _openParentSheet — mở bottom sheet chọn cha
  // =============================================
  Future<void> _openParentSheet() async {
    final provider = Provider.of<CategoryProvider>(context, listen: false);
    // Bước 1: Load danh sách cha phù hợp với loại hiện tại
    await provider.loadParents(_ctgType); // GET /api/categories/parents?type=...

    if (!mounted) return;

    // Bước 2: Mở BottomSheet — cho phép kéo giãn
    final result = await showModalBottomSheet<CategoryResponse?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // cho phép sheet cao hơn nửa màn hình
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        builder: (_, __) => ParentCategorySheet(
          parents: provider.parentCategories,
          selectedParentId: _effectiveParentId, // [FIX-1] dùng _effectiveParentId
        ),
      ),
    );

    // Cập nhật parentId theo kết quả chọn
    if (result != null) {
      // User chọn một danh mục cha cụ thể
      setState(() {
        _effectiveParentId = result.id;
        _parentDisplayName = result.ctgName;
      });
    } else {
      // User chọn "Không có nhóm cha"
      setState(() {
        _effectiveParentId = null;
        _parentDisplayName = null;
      });
    }
  }

  // =============================================
  // [6.5] _updateCategory — gọi API cập nhật
  // =============================================
  Future<void> _updateCategory() async {
    // Bước 1: Validate client-side
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar("Vui lòng nhập tên danh mục", isError: true);
      return;
    }

    // Bước 2: Build request
    // [FIX-1] Dùng _effectiveParentId — không dùng ?? fallback
    final request = CategoryRequest(
      ctgName: name,
      ctgType: _ctgType,
      ctgIconUrl: widget.category.ctgIconUrl,
      parentId: _effectiveParentId,
    );

    // Bước 3: Gọi API
    setState(() => _isSaving = true);

    final provider = Provider.of<CategoryProvider>(context, listen: false);
    final success = await provider.updateCategory(widget.category.id, request);

    setState(() => _isSaving = false);

    if (!mounted) return;

    // Bước 4: Xử lý kết quả
    if (success) {
      _showSnackBar(provider.successMessage ?? "Cập nhật thành công");
      Navigator.pop(context, true);
    } else {
      _showSnackBar(provider.errorMessage ?? "Có lỗi xảy ra", isError: true);
    }
  }

  // =============================================
  // [6.6] _deleteCategory — xóa (có confirm dialog)
  // =============================================
  Future<void> _deleteCategory() async {
    // Bước 1: Hiện dialog xác nhận trước khi xóa
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Xóa danh mục", style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc muốn xóa "${widget.category.ctgName}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    final provider = Provider.of<CategoryProvider>(context, listen: false);
    final success = await provider.deleteCategory(widget.category.id);

    // Bước 2: Gọi API xóa
    setState(() => _isDeleting = false);

    // Bước 3: Xử lý kết quả — lỗi thường gặp: 403 khi xóa danh mục hệ thống

    if (!mounted) return;

    if (success) {
      _showSnackBar(provider.successMessage ?? "Xóa thành công");
      Navigator.pop(context, true);
    } else {
      _showSnackBar(provider.errorMessage ?? "Không thể xóa", isError: true);
    }
  }

  // =============================================
  // [6.7] Helper — hiện SnackBar
  // =============================================
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // =============================================
  // [6.8] build
  // =============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Chỉnh sửa nhóm"),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== [A] Row 1: Icon + Tên =====
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // TODO: mở icon picker
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade800,
                    child: const Icon(Icons.category, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLength: 100, // khớp backend @Size(max = 100) trong CategoryRequest.java
                    decoration: const InputDecoration(
                      hintText: "Tên nhóm",
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

            // ===== [B] Row 2: Chọn loại =====
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
                  // Khoản chi
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _ctgType = false;
                          // [FIX-1] Xóa cha khi đổi loại
                          _effectiveParentId = null;
                          _parentDisplayName = null;
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            !_ctgType ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: !_ctgType ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text("Khoản chi",
                              style: TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  // Khoản thu
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _ctgType = true;
                          // [FIX-1] Xóa cha khi đổi loại
                          _effectiveParentId = null;
                          _parentDisplayName = null;
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            _ctgType ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: _ctgType ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text("Khoản thu",
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
              onTap: _openParentSheet,
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
                        // [FIX-2] Hiển thị tên cha thực sự
                        _parentDisplayName ?? "Chọn nhóm cha",
                        style: TextStyle(
                          color: _parentDisplayName != null ? Colors.white : Colors.grey,
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
                onPressed: _isSaving ? null : _updateCategory,
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
                    : const Text("Lưu",
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 12),

            // ===== [E] Button "Xóa" =====
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isDeleting ? null : _deleteCategory,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
                      )
                    : const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  "Xóa danh mục",
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
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

