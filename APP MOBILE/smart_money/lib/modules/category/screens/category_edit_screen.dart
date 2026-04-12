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
import 'package:smart_money/modules/category/models/icon_dto.dart';
import 'package:smart_money/modules/category/widgets/parent_category_sheet.dart';
import 'package:smart_money/modules/category/screens/icon_picker_screen.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  // Icon đã chọn (fileName) — khởi tạo từ category hiện tại, đổi khi user chọn icon mới
  String? _selectedIconFileName;
  // URL hiển thị — dùng khi user chọn icon mới từ picker
  String? _selectedIconUrl;

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

    // Bước 2b: Gán icon ban đầu từ category hiện tại
    _selectedIconFileName = widget.category.ctgIconUrl;

    // Bước 3: [FIX-2] Lấy tên cha trực tiếp từ server response (parentName)
    // → Không cần gọi API thừa, tránh lag & flicker loading spinner trên list screen
    _parentDisplayName = widget.category.parentName;
  }

  @override
  void dispose() {
    _nameController.dispose(); // giải phóng controller để tránh memory leak
    super.dispose();
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
  // [6.4b] _openIconPicker — mở màn hình chọn icon
  // =============================================
  void _openIconPicker() async {
    final result = await Navigator.push<IconDto>(
      context,
      MaterialPageRoute(
        builder: (_) => IconPickerScreen(
          currentIconFileName: _selectedIconFileName,
        ),
      ),
    );

    // Nếu user chọn icon mới → cập nhật state
    if (result != null && mounted) {
      setState(() {
        _selectedIconFileName = result.fileName; // lưu tên file để gửi lên server
        _selectedIconUrl = result.url;            // URL để hiển thị ngay
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
      _showSnackBar("Please enter a category name", isError: true);
      return;
    }

    // Bước 1.5: Confirm trước khi lưu — tránh bấm nhầm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Confirm Update', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to update "$name"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Bước 2: Build request
    // [FIX-1] Dùng _effectiveParentId — không dùng ?? fallback
    final request = CategoryRequest(
      ctgName: name,
      ctgType: _ctgType,
      ctgIconUrl: _selectedIconFileName,
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
      _showSnackBar(provider.successMessage ?? "Category updated successfully");
      Navigator.pop(context, true);
    } else {
      _showSnackBar(provider.errorMessage ?? "An error occurred", isError: true);
    }
  }

  // =============================================
  // [6.6] _deleteCategory — Xóa danh mục (DELETE_ALL)
  // =============================================
  // Step 1: Show a rich warning dialog with two options:
  //   - "Merge & Delete" → redirect to merge sheet (preserve transactions)
  //   - "Delete All"     → second confirm → hard DELETE_ALL (lose all transactions)
  // Step 2 (only for Delete All): second confirm to prevent accidental data loss
  Future<void> _deleteCategory() async {
    // Bước 1: Dialog cảnh báo với 2 lựa chọn
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
            SizedBox(width: 10),
            Text("Delete Category", style: TextStyle(color: Colors.white, fontSize: 17)),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.55),
            children: [
              TextSpan(
                text: '"${widget.category.ctgName}"',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: ' has transactions linked to it.\n\n'
                    '⚠️ ',
              ),
              const TextSpan(
                text: 'Deleting will permanently remove ALL transactions',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: ' in this category and all its subcategories.\n\n'
                    'To keep your history, use ',
              ),
              const TextSpan(
                text: '"Merge & Delete"',
                style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' to move transactions to another category first.'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.blueAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, 'merge'),
            child: const Text("Merge & Delete", style: TextStyle(color: Colors.blueAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text("Delete All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    // Bước 2a: User chọn Merge → mở sheet gộp (không xóa ngay)
    if (choice == 'merge') {
      _showMergeCategorySheet();
      return;
    }

    // Bước 2b: User chọn Delete All → xác nhận lần 2
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Delete All", style: TextStyle(color: Colors.white)),
        content: const Text(
          'This action CANNOT be undone.\nAll transactions will be permanently lost.',
          style: TextStyle(color: Colors.grey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete Permanently", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Bước 3: Gọi API xóa với actionType=DELETE_ALL
    setState(() => _isDeleting = true);

    final provider = Provider.of<CategoryProvider>(context, listen: false);
    final success = await provider.deleteCategoryWithOptions(
      id: widget.category.id,
      actionType: "DELETE_ALL",
    );

    setState(() => _isDeleting = false);
    if (!mounted) return;

    // Bước 3: Kết quả
    if (success) {
      _showSnackBar(provider.successMessage ?? "Category deleted successfully");
      Navigator.pop(context, true);
    } else {
      _showSnackBar(provider.errorMessage ?? "Failed to delete category", isError: true);
    }
  }

  // =============================================
  // [6.6.2] Sheet chọn danh mục nhận gộp (MERGE)
  // =============================================
  // API: GET /api/categories/merge-targets?type={ctgType}
  // Lọc: cùng loại (Thu/Chi), loại bỏ chính nó
  // User chọn xong → gọi DELETE?actionType=MERGE&newCategoryId=X
  Future<void> _showMergeCategorySheet() async {
    final provider = Provider.of<CategoryProvider>(context, listen: false);

    // Bước 1: Load danh sách danh mục nhận gộp
    await provider.loadMergeTargets(
      widget.category.ctgType ?? false,
      excludeId: widget.category.id,
    );
    if (!mounted) return;

    // Bước 2: Kiểm tra danh sách rỗng
    if (provider.mergeTargets.isEmpty) {
      _showSnackBar("No categories of the same type available for merging", isError: true);
      return;
    }

    // Bước 3: Mở BottomSheet chọn danh mục nhận
    final selected = await showModalBottomSheet<CategoryResponse?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        builder: (_, __) => _MergeTargetSheet(
          targets: provider.mergeTargets,
          categoryName: widget.category.ctgName,
        ),
      ),
    );

    if (selected == null || !mounted) return; // user đóng sheet không chọn

    // Bước 4: Gọi API gộp
    setState(() => _isDeleting = true);

    final success = await provider.deleteCategoryWithOptions(
      id: widget.category.id,
      actionType: "MERGE",
      newCategoryId: selected.id,
    );

    setState(() => _isDeleting = false);
    if (!mounted) return;

    if (success) {
      _showSnackBar(provider.successMessage ?? "Category merged successfully");
      Navigator.pop(context, true);
    } else {
      _showSnackBar(provider.errorMessage ?? "Failed to merge category", isError: true);
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
        title: const Text("Edit Category"),
        backgroundColor: Colors.black,
        centerTitle: true,
        actions: [
          // Nút xóa ở bên phải appbar (icon thùng rác)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: GestureDetector(
                onTap: _isDeleting ? null : _deleteCategory,
                child: _isDeleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.red,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.delete_outline, color: Colors.red, size: 24),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ===== [A] Row 1: Icon + Tên =====
            Row(
              children: [
                GestureDetector(
                  onTap: _openIconPicker,
                  child: _buildCategoryIcon(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLength: 100, // khớp backend @Size(max = 100) trong CategoryRequest.java
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

            // ===== [B] Row 2: Loại Thu/Chi — LOCKED, không thể thay đổi khi sửa =====
            // [TYPE-LOCK] ctgType được khóa khi edit để tránh làm sai dữ liệu giao dịch.
            // Muốn đổi loại → xóa và tạo lại category mới.
            IgnorePointer( // chặn toàn bộ gesture trong container này
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  // Viền mờ để nhận ra là disabled
                  border: Border.all(color: Colors.grey.shade800, width: 1),
                ),
                child: Row(
                  children: [
                    // Icon khóa thay vì swap_horiz — báo hiệu field này bị locked
                    const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                    const SizedBox(width: 12),
                    // Expense radio — hiển thị trạng thái nhưng không click được
                    Expanded(
                      child: Opacity(
                        opacity: 0.5,
                        child: Row(
                          children: [
                            Icon(
                              !_ctgType ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: !_ctgType ? Colors.green : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text("Expense",
                                style: TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    // Income radio — hiển thị trạng thái nhưng không click được
                    Expanded(
                      child: Opacity(
                        opacity: 0.5,
                        child: Row(
                          children: [
                            Icon(
                              _ctgType ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: _ctgType ? Colors.green : Colors.grey,
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
                        // [FIX-2] Hiển thị tên cha thực sự, fallback về placeholder nếu chưa chọn
                        _parentDisplayName ?? "Select parent category",
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

            const SizedBox(height: 12),

            // ===== [C.1] Nút MERGE CATEGORY =====
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _isDeleting ? null : _showMergeCategorySheet,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  "MERGE CATEGORY",
                  style: TextStyle(color: Colors.blue, fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

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
                    : const Text("Save",
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // =============================================
  // _buildCategoryIcon — hiển thị icon từ Cloudinary
  // =============================================
  // Ưu tiên: icon vừa chọn mới (_selectedIconUrl) > icon gốc (widget.category.ctgIconUrl)
  Widget _buildCategoryIcon() {
    // Nếu user vừa chọn icon mới → dùng URL trực tiếp từ picker
    String? displayUrl = _selectedIconUrl;
    
    // Nếu chưa chọn icon mới → dùng icon gốc (convert từ fileName)
    if (displayUrl == null) {
      displayUrl = IconHelper.buildCloudinaryUrl(_selectedIconFileName);
    }
    
    if (displayUrl != null && displayUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade800,
        child: CachedNetworkImage(
          imageUrl: displayUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (_, __) => const Icon(Icons.category, color: Colors.white, size: 24),
          errorWidget: (_, __, ___) => const Icon(Icons.category, color: Colors.white, size: 24),
        ),
      );
    }
    
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey.shade800,
      child: const Icon(Icons.category, color: Colors.white, size: 24),
    );
  }
}

// ===========================================================
// [6.9] Widget nội bộ: Sheet chọn danh mục nhận gộp
// ===========================================================
// Hiện khi: User chọn "Gộp giao dịch" từ dialog [6.6.1]
// Layout: giống ParentCategorySheet nhưng không có option "Không có"
// Return: CategoryResponse đã chọn (hoặc null nếu đóng sheet)
class _MergeTargetSheet extends StatelessWidget {
  // Danh sách danh mục cùng loại có thể nhận gộp
  final List<CategoryResponse> targets;
  // Tên danh mục đang bị xóa — hiển thị trong tiêu đề
  final String categoryName;

  const _MergeTargetSheet({
    required this.targets,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Expanded(
                  child: Text(
                    'Move transactions from "$categoryName" to:',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(context), // đóng sheet, không chọn
                  child: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.grey),

          // ----- Danh sách danh mục nhận gộp -----
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: targets.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.grey),
              itemBuilder: (context, index) {
                final target = targets[index];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade800,
                    child: const Icon(Icons.category, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    target.ctgName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  // Hiển thị loại (Thu/Chi) nhỏ bên dưới
                  subtitle: Text(
                    target.ctgType == true ? "Income" : "Expense",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context, target), // trả về danh mục đã chọn
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}




