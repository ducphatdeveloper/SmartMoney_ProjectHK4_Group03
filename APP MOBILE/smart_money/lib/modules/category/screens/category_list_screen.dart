// ===========================================================
// [4] Màn hình 1: Danh sách Danh mục (CategoryListScreen)
// ===========================================================
// Giao diện chính của module Category
// Layout:
//   • AppBar: "Nhóm" + icon tìm kiếm
//   • TabBar: 3 tab — Khoản chi | Khoản thu | Vay/Nợ
//   • Body: CategoryTabContent cho mỗi tab
//
// Flow:
//   1. initState → load danh mục tab đầu tiên (expense)
//   2. Chuyển tab → load danh mục theo group tương ứng
//   3. Bấm "Nhóm mới" → navigate sang CategoryCreateScreen
//   4. Bấm vào danh mục → navigate sang CategoryEditScreen
// ===========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/category/providers/category_provider.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/modules/category/widgets/category_tab_content.dart';
import 'category_create_screen.dart';
import 'category_edit_screen.dart';
import 'category_search_screen.dart'; // màn hình tìm kiếm

class CategoryListScreen extends StatefulWidget {
  /// Khi true: bấm vào danh mục → pop trả CategoryResponse (dùng cho chọn nhóm khi tạo giao dịch)
  /// Khi false: bấm vào danh mục → navigate sang edit (hành vi mặc định)
  final bool isSelectMode;

  /// Tab ban đầu khi mở ở select mode: 'expense' | 'income' | 'debt'
  final String? initialTab;

  const CategoryListScreen({
    super.key,
    this.isSelectMode = false,
    this.initialTab,
  });

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  // TabController cho 3 tab
  late TabController _tabController;

  // Map index tab → tên group gửi lên API
  final List<String> _tabGroups = ['expense', 'income', 'debt'];

  // =============================================
  // [4.1] initState — khởi tạo tab + load dữ liệu ban đầu
  // =============================================
  @override
  void initState() {
    super.initState();

    // Xác định tab ban đầu từ initialTab
    int initialIndex = 0;
    if (widget.initialTab != null) {
      final idx = _tabGroups.indexOf(widget.initialTab!);
      if (idx >= 0) initialIndex = idx;
    }

    // Bước 1: Tạo TabController 3 tab
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);

    // Bước 2: Lắng nghe khi chuyển tab → load danh mục theo group
    _tabController.addListener(_onTabChanged);

    // Bước 3: Load danh mục tab ban đầu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CategoryProvider>(context, listen: false);
      provider.loadByGroup(_tabGroups[initialIndex]);
    });

    // Bước 4: Đăng ký lắng nghe app lifecycle (resume từ background)
    WidgetsBinding.instance.addObserver(this);
  }

  // =============================================
  // [4.1b] didChangeAppLifecycleState — xử lý khi quay lại app
  // =============================================
  // Khi user quay lại từ screen khác (transaction list, etc.)
  // → Clear cache toàn bộ → reload data lần đầu tiên vào tab
  // Lợi ích: Đảm bảo dữ liệu luôn fresh, không bị dính cache stale
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Khi user quay lại app từ background → xóa cache
      final provider = Provider.of<CategoryProvider>(context, listen: false);
      provider.clearCache();
      // Load lại tab hiện tại (sẽ gọi API do cache được xóa)
      provider.loadByGroup(_tabGroups[_tabController.index]);
    }
  }

  // =============================================
  // [4.2] _onTabChanged — xử lý khi chuyển tab
  // =============================================
  // Logic:
  //   • Nếu tab đã từng load (có cache) → hiện cache (mượt, 0 lag)
  //   • Nếu tab chưa load → gọi API (lần đầu)
  //   • Không gọi API mỗi khi chuyển tab → tránh lag
  void _onTabChanged() {
    // Chỉ xử lý khi tab thực sự đổi (tránh gọi 2 lần)
    if (!_tabController.indexIsChanging) return;

    final group = _tabGroups[_tabController.index];
    final provider = Provider.of<CategoryProvider>(context, listen: false);
    
    // Gọi loadByGroup mà không force refresh
    // → Nếu đã cache trước đó → dùng cache (mượt)
    // → Nếu chưa cache → gọi API lần đầu
    provider.loadByGroup(group, forceRefresh: false);
  }

  // =============================================
  // [4.3] dispose — giải phóng tài nguyên
  // =============================================
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // huỷ đăng ký lifecycle
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  // =============================================
  // [4.3b] _navigateToSearch — mở màn hình tìm kiếm
  // =============================================
  void _navigateToSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategorySearchScreen()),
    );

    // Luôn reload tab hiện tại khi quay về (có thể đã sửa/xóa từ search)
    if (mounted) {
      final provider = Provider.of<CategoryProvider>(context, listen: false);
      provider.loadByGroup(_tabGroups[_tabController.index], forceRefresh: true);
    }
  }

  // =============================================
  // [4.4] _navigateToCreate — mở màn hình tạo mới
  // =============================================
  void _navigateToCreate() async {
    // Lấy ctgType từ tab đang chọn (expense → false, income → true)
    final currentGroup = _tabGroups[_tabController.index];
    final ctgType = currentGroup == 'income'; // true = Thu, false = Chi

    // Navigate sang CategoryCreateScreen
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryCreateScreen(defaultCtgType: ctgType),
      ),
    );

    // Nếu tạo thành công (result == true) → reload danh sách
    if (result == true && mounted) {
      final provider = Provider.of<CategoryProvider>(context, listen: false);
      provider.loadByGroup(_tabGroups[_tabController.index], forceRefresh: true);
    }
  }

  // =============================================
  // [4.5] _onCategoryTap — xử lý khi bấm vào danh mục
  // =============================================
  void _onCategoryTap(CategoryResponse category) {
    if (widget.isSelectMode) {
      // Select mode → trả category về cho screen gọi (TransactionCreateScreen)
      Navigator.pop(context, category);
    } else {
      // Normal mode → mở edit
      _navigateToEdit(category);
    }
  }

  // =============================================
  // [4.5b] _navigateToEdit — mở màn hình chỉnh sửa
  // =============================================
  void _navigateToEdit(CategoryResponse category) async {
    // Danh mục hệ thống (account == null trên server) → kiểm tra quyền ở server
    // Ở đây vẫn cho navigate, server sẽ trả lỗi nếu không có quyền

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryEditScreen(category: category),
      ),
    );

    // Nếu sửa/xóa thành công → reload
    if (result == true && mounted) {
      final provider = Provider.of<CategoryProvider>(context, listen: false);
      provider.loadByGroup(_tabGroups[_tabController.index], forceRefresh: true);
    }
  }

  // =============================================
  // [4.6] build — giao diện chính
  // =============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.isSelectMode ? "Select category" : "Categories"),
        backgroundColor: Colors.black,
        centerTitle: true,
        leading: const BackButton(),
        actions: [
          // Icon tìm kiếm — chỉ hiện ở normal mode
          if (!widget.isSelectMode)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: _navigateToSearch,
            ),
        ],

        // ===== TabBar 3 tab — chia đều, line trắng dưới tab đang chọn =====
        bottom: TabBar(
          controller: _tabController,
          // Indicator: line trắng bên dưới tab đang chọn
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          // Tab đang chọn: nền xanh lá, chữ trắng
          labelColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          // Tab không chọn: chữ xám
          unselectedLabelColor: Colors.grey,
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          dividerColor: Colors.transparent,
          // Nền cho tab đang chọn — dùng BoxDecoration qua indicator
          indicator: const BoxDecoration(
            color: Color(0xFF4CAF50), // nền xanh lá cho tab đang chọn
            border: Border(
              bottom: BorderSide(color: Colors.white, width: 3),
            ),
          ),
          tabs: const [
            Tab(text: "Expense"),
            Tab(text: "Income"),
            Tab(text: "Debt"),
          ],
        ),
      ),

      // ===== Body: TabBarView với 3 tab =====
      body: RefreshIndicator(
        onRefresh: () async {
          // Khi user pull-to-refresh → clear cache + load tab hiện tại
          final provider = Provider.of<CategoryProvider>(context, listen: false);
          provider.clearCache();
          await provider.loadByGroup(_tabGroups[_tabController.index]);
        },
        child: TabBarView(
          controller: _tabController,
          // 1. Physics: PageScrollPhysics → cuộn như page (mượt)
          // 2. Drag từ phải sang trái → chuyển tab → list lướt từ phải sang trái
          // 3. Drag từ trái sang phải → chuyển tab → list lướt từ trái sang phải
          physics: const PageScrollPhysics(),
          children: [
            // Tab 1: Khoản chi
            CategoryTabContent(
              group: 'expense',
              onAddNew: widget.isSelectMode ? null : _navigateToCreate,
              onTapCategory: _onCategoryTap,
            ),
            // Tab 2: Khoản thu
            CategoryTabContent(
              group: 'income',
              onAddNew: widget.isSelectMode ? null : _navigateToCreate,
              onTapCategory: _onCategoryTap,
            ),
            // Tab 3: Vay/Nợ — không có nút "Nhóm mới"
            CategoryTabContent(
              group: 'debt',
              onAddNew: null, // không cho tạo mới ở tab Vay/Nợ
              onTapCategory: _onCategoryTap,
            ),
          ],
        ),
      ),
    );
  }
}

