// ===========================================================
// [4] DebtListScreen — Màn hình chính Sổ Nợ
// ===========================================================
// Trách nhiệm:
//   • Hiển thị 2 Tab: CẦN TRẢ (debtType=false) và CẦN THU (debtType=true)
//   • Mỗi Tab chia làm 2 section: CHƯA TRẢ/THU và ĐÃ TRẢ/NHẬN HẾT
//   • Pull-to-refresh để tải lại danh sách
//   • Navigate sang DebtDetailScreen khi tap vào khoản nợ
//
// Layout:
//   • AppBar: "Sổ nợ" + wallet picker icon
//   • TabBar: CẦN TRẢ | CẦN THU
//   • FAB: (không có — debt tạo qua Transaction)
//   • Body: ListView với DebtSectionHeaderWidget + DebtCardWidget
//
// Flow:
//   1. initState → loadDebts(false) và loadDebts(true) song song
//   2. Tap card → push DebtDetailScreen → await kết quả → reload nếu có thay đổi
//   3. Pull-to-refresh → gọi lại loadDebts theo tab đang active
//
// Lỗi từ server:
//   • Không có lỗi đặc biệt ở list — lỗi 401/403 ApiHandler tự xử lý
//
// Gọi từ:
//   • AppRouter / BottomNavigationBar → màn hình tab chính
// ===========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import '../models/debt_response.dart';
import '../providers/debt_provider.dart';
import '../widgets/debt_card_widget.dart';
import '../widgets/debt_section_header_widget.dart';
import 'debt_detail_screen.dart';

class DebtListScreen extends StatefulWidget {
  const DebtListScreen({super.key});

  @override
  State<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends State<DebtListScreen>
    with SingleTickerProviderStateMixin {

  // =============================================
  // [4.1] STATE
  // =============================================

  late TabController _tabController; // quản lý Tab CẦN TRẢ / CẦN THU

  // =============================================
  // [4.2] LIFECYCLE
  // =============================================

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Tải cả 2 tab ngay khi vào màn hình để không lag khi chuyển tab
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose(); // giải phóng TabController tránh memory leak
    super.dispose();
  }

  // =============================================
  // [4.3] LOAD
  // =============================================

  // Tải cả 2 tab song song khi khởi tạo hoặc refresh
  Future<void> _loadAll() async {
    final provider = context.read<DebtProvider>();
    await Future.wait([
      provider.loadDebts(false), // Tab CẦN TRẢ
      provider.loadDebts(true),  // Tab CẦN THU
    ]);
  }

  // Pull-to-refresh cho tab đang active
  Future<void> _onRefresh() async {
    final provider = context.read<DebtProvider>();
    // Làm mới tab đang xem
    final isPayableTab = _tabController.index == 0;
    await provider.loadDebts(!isPayableTab); // false=CẦN TRẢ, true=CẦN THU
  }

  // =============================================
  // [4.4] NAVIGATE
  // =============================================

  // Mở DebtDetailScreen, reload list khi quay về (nếu có thay đổi)
  Future<void> _openDetail(DebtResponse debt) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<DebtProvider>(),
          child: DebtDetailScreen(debtId: debt.id, debtType: debt.debtType),
        ),
      ),
    );

    // [IMPORTANT] Reload list nếu user đã sửa/xóa/toggle ở Detail screen
    if (changed == true && mounted) {
      final isPayableTab = _tabController.index == 0;
      context.read<DebtProvider>().loadDebts(!isPayableTab);
    }
  }

  // =============================================
  // [4.5] BUILD
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // TabBar nằm ngoài TabBarView để giữ sticky khi scroll
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 0: CẦN TRẢ (debtType=false)
                _buildTab(isPayable: true),
                // Tab 1: CẦN THU (debtType=true)
                _buildTab(isPayable: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Sổ nợ'),
      centerTitle: false,
      // [TODO] Thêm wallet picker icon khi có thời gian
      // actions: [IconButton(icon: ..., onPressed: ...)],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: TabBar(
        controller: _tabController,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: 'CẦN TRẢ'),
          Tab(text: 'CẦN THU'),
        ],
      ),
    );
  }

  // Nội dung từng Tab (dùng chung cho cả 2)
  Widget _buildTab({required bool isPayable}) {
    return Consumer<DebtProvider>(
      builder: (context, provider, _) {
        // Đang tải → hiện spinner
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Lấy đúng list tương ứng với tab
        final activeList = isPayable
            ? provider.payableDebts     // Cần Trả, chưa xong
            : provider.receivableDebts; // Cần Thu, chưa xong
        final doneList = isPayable
            ? provider.payableDone      // Cần Trả, đã xong
            : provider.receivableDone;  // Cần Thu, đã xong

        // Cả 2 list đều trống → hiện empty state
        if (activeList.isEmpty && doneList.isEmpty) {
          return _buildEmptyState(isPayable);
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ----- Section 1: CHƯA TRẢ / CHƯA THU -----
              if (activeList.isNotEmpty) ...[
                DebtSectionHeaderWidget(
                  label: isPayable ? 'CHƯA TRẢ' : 'CHƯA THU',
                  // Tổng số tiền còn phải trả/thu
                  totalAmount: activeList.fold(0, (sum, d) => sum + d.remainAmount),
                  color: isPayable ? Colors.red[600]! : Colors.blue[600]!,
                ),
                ...activeList.map((debt) => DebtCardWidget(
                  debt: debt,
                  onTap: () => _openDetail(debt),
                )),
              ],

              // ----- Section 2: ĐÃ TRẢ HẾT / ĐÃ NHẬN HẾT -----
              if (doneList.isNotEmpty) ...[
                DebtSectionHeaderWidget(
                  label: isPayable ? 'ĐÃ TRẢ HẾT' : 'ĐÃ NHẬN HẾT',
                  totalAmount: doneList.fold(0, (sum, d) => sum + d.totalAmount),
                  color: Colors.grey[500]!,
                ),
                ...doneList.map((debt) => DebtCardWidget(
                  debt: debt,
                  onTap: () => _openDetail(debt),
                )),
              ],

              const SizedBox(height: 80), // padding bottom
            ],
          ),
        );
      },
    );
  }

  // Empty state khi chưa có khoản nợ nào
  Widget _buildEmptyState(bool isPayable) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.handshake_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            isPayable
                ? 'Bạn chưa có khoản vay nào'
                : 'Bạn chưa có khoản cho vay nào',
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'Tạo giao dịch "${isPayable ? 'Đi vay' : 'Cho vay'}" để bắt đầu',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
