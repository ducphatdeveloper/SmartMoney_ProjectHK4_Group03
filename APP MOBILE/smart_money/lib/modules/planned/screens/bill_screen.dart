// ===========================================================
// [5] BillScreen — Màn hình Hóa đơn (2 tab: Đang áp dụng / Đã kết thúc)
// ===========================================================
// Layout:
//   • AppBar: nút back + "Hoá đơn" + Dropdown chọn ví (BottomSheet)
//   • Row: nút [+] tròn xanh → push PlannedFormScreen(bill)
//   • Banner: "Chúc mừng đã trả hết" hoặc "Còn X chưa trả"
//   • TabBar 2 tab: [ĐANG ÁP DỤNG] [ĐÃ KẾT THÚC]
//   • TabBarView:
//     - Tab 0: Banner + ListView BillListItem (active) — nút "Trả tiền"/"Đã trả"
//     - Tab 1: ListView BillListItem (expired)
//
// Flow:
//   1. initState: load danh sách (active + expired song song)
//   2. User bấm [+] → push PlannedFormScreen
//   3. User tap item → mở BillDetailSheet (có nút sửa + xóa + xem giao dịch)
//   4. User bấm "Trả tiền" trên list item → provider.payBill()
//   5. User chọn ví trong AppBar → lọc local
//
// API liên quan:
//   • GET  /api/bills?active=true|false — load danh sách
//   • DELETE /api/bills/{id}            — xóa
//   • PATCH  /api/bills/{id}/toggle     — đánh dấu hoàn tất
//   • POST   /api/bills/{id}/pay        — trả tiền
// ===========================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/planned/enums/plan_type.dart';
import 'package:smart_money/modules/planned/models/planned_transaction_response.dart';
import 'package:smart_money/modules/planned/providers/bill_provider.dart';
import 'package:smart_money/modules/planned/screens/planned_form_screen.dart';
import 'package:smart_money/modules/planned/widgets/bill_list_item.dart';
import 'package:smart_money/modules/transaction/services/util_service.dart';
import 'package:smart_money/modules/wallet/models/wallet_response.dart';
import 'package:smart_money/modules/planned/screens/bill_transaction_list_screen.dart'; // Import mới

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> with SingleTickerProviderStateMixin {

  // =============================================
  // [5.1] STATE
  // =============================================
  late TabController _tabController; // 2 tab: ĐANG ÁP DỤNG + ĐÃ KẾT THÚC

  // Danh sách ví (load trực tiếp từ UtilService, không phụ thuộc WalletProvider)
  List<WalletResponse> _wallets = [];
  bool _isLoadingWallets = false;

  // =============================================
  // [5.2] initState
  // =============================================
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<BillProvider>(context, listen: false);
      provider.loadAll();
    });

    // Load wallets từ UtilService (tự auth, không cần token)
    _loadWallets();
  }

  /// Load danh sách ví cơ bản từ API (planned không dùng SavingGoal)
  Future<void> _loadWallets() async {
    _isLoadingWallets = true;
    if (mounted) setState(() {});

    try {
      final response = await UtilService.getAllWallets();
      if (response.success && response.data != null) {
        _wallets = response.data!;
      }
    } catch (e) {
      debugPrint('❌ [BillScreen] Lỗi tải ví: $e');
    }

    _isLoadingWallets = false;
    if (mounted) setState(() {});
  }

  // =============================================
  // [5.3] dispose
  // =============================================
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =============================================
  // [5.4] BUILD
  // =============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  // =============================================
  // [5.5] APP BAR + TABS
  // =============================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1C1C1E),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      // [TODO i18n] Screen title
      title: const Text(
        'Hoá đơn',
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      actions: [_buildWalletDropdown()],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF4CAF50),
        labelColor: const Color(0xFF4CAF50),
        unselectedLabelColor: const Color(0xFF8E8E93),
        tabs: const [
          Tab(text: 'ĐANG ÁP DỤNG'),
          Tab(text: 'ĐÃ KẾT THÚC'),
        ],
      ),
    );
  }

  // =============================================
  // [5.6] WALLET DROPDOWN — BottomSheet chọn ví với icon + balance
  // =============================================
  // [FIX-2] Đổi từ DropdownButton → GestureDetector + showModalBottomSheet
  // Hiện icon ví + tên + số dư. Không dùng SavingGoal (planned chỉ dùng wallet).
  Widget _buildWalletDropdown() {
    return Consumer<BillProvider>(
      builder: (context, billProv, _) {
        final wallets = _wallets;
        final selected = billProv.selectedWalletId;

        // Tìm tên ví đang chọn để hiển thị trên AppBar
        String displayName = 'Tất cả ví';
        if (selected != null) {
          final found = wallets.where((w) => w.id == selected);
          if (found.isNotEmpty) displayName = found.first.walletName;
        }

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: _isLoadingWallets ? null : () => _showWalletFilterSheet(wallets, billProv),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxWidth: 200),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon ví nhỏ
                  if (selected != null) ...[
                    _buildSmallWalletIcon(
                      wallets.where((w) => w.id == selected).isNotEmpty
                          ? wallets.firstWhere((w) => w.id == selected).goalImageUrl
                          : null,
                    ),
                    const SizedBox(width: 6),
                  ] else ...[
                    // Khi 'Tất cả ví' được chọn, hiển thị icon màu xanh lá giống trang transaction
                    const Icon(Icons.account_balance_wallet, color: Color(0xFF4CAF50), size: 18),
                    const SizedBox(width: 6),
                  ],
                  // Tên ví
                  Flexible(
                    child: Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E8E93), size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── BottomSheet danh sách ví — icon + tên + balance ──
  void _showWalletFilterSheet(List<WalletResponse> wallets, BillProvider billProv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            // [TODO i18n] Wallet picker header
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chọn ví', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1, color: Color(0xFF3A3A3C)),

            // Item "Tất cả ví"
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  // Dùng màu xanh lá cho nền "Tất cả ví" để đồng bộ với trang giao dịch
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
              ),
              title: Text(
                'Tất cả ví',
                style: TextStyle(
                  color: billProv.selectedWalletId == null ? const Color(0xFF4CAF50) : Colors.white,
                  fontWeight: billProv.selectedWalletId == null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: billProv.selectedWalletId == null
                  ? const Icon(Icons.check, color: Color(0xFF4CAF50))
                  : null,
              onTap: () {
                billProv.setWalletFilter(null);
                Navigator.pop(ctx);
              },
            ),

            // Danh sách wallet
            ...wallets.map((w) {
              final isSelected = billProv.selectedWalletId == w.id;
              return ListTile(
                leading: _buildWalletSheetIcon(w.goalImageUrl),
                title: Text(
                  w.walletName,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF4CAF50) : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  FormatHelper.formatVND(w.balance),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Color(0xFF4CAF50))
                    : null,
                onTap: () {
                  billProv.setWalletFilter(w.id);
                  Navigator.pop(ctx);
                },
              );
            }),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // ── Helper: Icon ví trong BottomSheet (40x40) ──
  Widget _buildWalletSheetIcon(String? iconUrl) {
    final cloudinaryUrl = IconHelper.buildCloudinaryUrl(iconUrl);
    if (cloudinaryUrl != null && cloudinaryUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cloudinaryUrl,
        width: 40, height: 40, fit: BoxFit.cover,
        imageBuilder: (context, imageProvider) => Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        placeholder: (_, __) => _buildDefaultWalletIcon(),
        errorWidget: (_, __, ___) => _buildDefaultWalletIcon(),
      );
    }
    return _buildDefaultWalletIcon();
  }

  // ── Helper: Icon ví nhỏ trên AppBar (18x18) ──
  Widget _buildSmallWalletIcon(String? iconUrl) {
    final cloudinaryUrl = IconHelper.buildCloudinaryUrl(iconUrl);
    if (cloudinaryUrl != null && cloudinaryUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cloudinaryUrl,
        width: 18, height: 18, fit: BoxFit.cover,
        imageBuilder: (context, imageProvider) => Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        placeholder: (_, __) => const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 18),
        errorWidget: (_, __, ___) => const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 18),
      );
    }
    return const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 18);
  }

  Widget _buildDefaultWalletIcon() {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.green.shade400,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
    );
  }

  // =============================================
  // [5.7] BODY — Nút + TabBarView
  // =============================================
  Widget _buildBody() {
    return SafeArea(
      child: Consumer<BillProvider>(
        builder: (context, provider, _) {
          // Loading
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
          }

          return Column(
            children: [
              // Nút [+] tạo mới
              Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => _openCreateForm(),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Thêm hóa đơn',
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFF3A3A3C)),

              // TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveTab(provider),
                    _buildExpiredTab(provider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // =============================================
  // [5.8] TAB ĐANG ÁP DỤNG — Có banner + list + nút "Trả tiền"
  // =============================================
  Widget _buildActiveTab(BillProvider provider) {
    final items = provider.activeItems;

    if (items.isEmpty) {
      return _buildEmptyState('Chưa có hóa đơn nào.\nNhấn + để thêm mới.');
    }

    // [v2] Đếm hóa đơn chưa trả/đã trả từ displayStatus (thay isPaidThisCycle)
    final unpaidCount = items.where((b) => b.displayStatus != 'PAID').length;
    final paidCount   = items.where((b) => b.displayStatus == 'PAID').length;
    // allPaid = true khi tất cả đều đã trả kỳ này
    final allPaid = unpaidCount == 0 && paidCount > 0;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        // ✅ BANNER — "Chúc mừng! Bạn đã trả tất cả hóa đơn kỳ này." hoặc "⚠️ Còn X hóa đơn chưa trả"
        if (allPaid)
          _buildBanner(
            '✅ Chúc mừng! Bạn đã trả tất cả hóa đơn kỳ này. 🎉',
            const Color(0xFF4CAF50),
          )
        else if (unpaidCount > 0)
          _buildBanner(
            '⚠️ Còn $unpaidCount hóa đơn chưa trả',
            const Color(0xFFFF9500),
          ),

        // Section header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Hóa đơn tiếp theo',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),

        // Danh sách hóa đơn active — onPay thay cho onEdit/onDelete
        ...items.map((item) => BillListItem(
          item: item,
          isExpired: false,
          onTap: () => _openBillDetailSheet(item),
          onPay: () => _handlePayBill(item),
        )),
      ],
    );
  }

  // =============================================
  // [5.8b] BANNER — Widget banner thông báo
  // =============================================
  Widget _buildBanner(String text, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.fromARGB(
          (color.alpha * 0.1).round().clamp(0, 255),
          (color.red * 255).round().clamp(0, 255),
          (color.green * 255).round().clamp(0, 255),
          (color.blue * 255).round().clamp(0, 255),
        ),
        border: Border.all(
          color: Color.fromARGB(
            (color.alpha * 0.5).round().clamp(0, 255),
            (color.red * 255).round().clamp(0, 255),
            (color.green * 255).round().clamp(0, 255),
            (color.blue * 255).round().clamp(0, 255),
          ),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [5.9] TAB ĐÃ KẾT THÚC
  // =============================================
  Widget _buildExpiredTab(BillProvider provider) {
    final items = provider.expiredItems;

    if (items.isEmpty) {
      return _buildEmptyState('Không có hóa đơn đã kết thúc.');
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Các hóa đơn đã kết thúc',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        ...items.map((item) => BillListItem(
          item: item,
          isExpired: true,
          onTap: () => _openBillDetailSheet(item),
        )),
      ],
    );
  }

  // =============================================
  // [5.10] EMPTY STATE
  // =============================================
  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 64, color: Color(0xFF8E8E93)),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [5.11] BILL DETAIL SHEET — Bottom sheet chi tiết hóa đơn
  // =============================================
  // [FIX-4] Nút sửa + xóa dời vào đây. Thêm nút "Xem giao dịch".
  void _openBillDetailSheet(PlannedTransactionResponse item) {
    final isIncome = item.categoryType == true;
    final amountColor = isIncome ? const Color(0xFF4CAF50) : const Color(0xFFFF6B6B);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Icon + Tên category
              IconHelper.buildCircleAvatar(iconUrl: item.categoryIcon, radius: 24),
              const SizedBox(height: 6),
              Text(
                item.categoryName ?? 'Hóa đơn',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),

              // Số tiền
              Text(
                FormatHelper.formatVND(item.amount),
                style: TextStyle(color: amountColor, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Ngày tiếp theo — dùng nextDueDateLabel từ Backend nếu có
              if (item.nextDueDateLabel != null) ...[
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF8E8E93)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hóa đơn tiếp theo là ${item.nextDueDateLabel}',
                        style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ] else if (item.nextDueDate != null) ...[
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF8E8E93)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hóa đơn tiếp theo là ${DateFormat("EEEE, dd 'tháng' M yyyy", 'vi_VN').format(item.nextDueDate!)}',
                        style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Số lần lặp lại còn lại (chỉ khi lặp theo COUNT)
              if (item.remainingCount != null && item.repeatType == 3) ...[
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF8E8E93)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Còn ${item.remainingCount} lần lặp lại',
                        style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Ví + Hết hạn cùng hàng
              if (item.walletName != null) ...[
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 16, color: Color(0xFF8E8E93)),
                    const SizedBox(width: 8),
                    Text(
                      item.walletName!,
                      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                    ),
                    const Spacer(),
                    if (item.displayStatus == 'OVERDUE')
                      _buildInlineExpiryLabel(item.statusLabel ?? 'Quá hạn', const Color(0xFFFF3B30))
                    else if (item.nextDueDate != null)
                      _buildInlineExpiryFromDate(item.nextDueDate!),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // ── Nút: ĐÁNH DẤU HOÀN TẤT ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(
                    item.active == true ? Icons.check_circle_outline : Icons.undo,
                    color: const Color(0xFF4CAF50),
                  ),
                  label: Text(
                    item.active == true ? 'ĐÁNH DẤU HOÀN TẤT' : 'ĐÁNH DẤU CHƯA HOÀN TẤT',
                    style: const TextStyle(color: Color(0xFF4CAF50)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF4CAF50)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final provider = Provider.of<BillProvider>(context, listen: false);
                    final success = await provider.toggle(item.id);
                    if (!mounted) return;
                    if (success) {
                      // Reload list after toggle to update UI immediately
                      provider.loadAll();
                      _showSnackBar('Đã cập nhật trạng thái hóa đơn');
                    } else {
                      _showSnackBar(provider.errorMessage ?? 'Có lỗi xảy ra', isError: true);
                    }
                  },
                ),
              ),
              const SizedBox(height: 6),

              // ── Nút: DANH SÁCH GIAO DỊCH (vị trí giữa, full width) ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_outlined, color: Color(0xFF8E8E93), size: 18),
                  label: const Text(
                    'Danh sách giao dịch',
                    style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3A3C),
                    side: const BorderSide(color: Color(0xFF3A3A3C)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BillTransactionListScreen(
                          billId: item.id,
                          billName: item.categoryName ?? 'Hóa đơn',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),

              // ── Hàng nút: SỬA + TRẢ X đ + XÓA ──
              Row(
                children: [
                  // Nút SỬA
                  if (item.active == true)
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF4CAF50), size: 18),
                        label: const Text('Sửa', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF4CAF50)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openEditForm(item);
                        },
                      ),
                    ),
                  if (item.active == true) const SizedBox(width: 8),

                  // Nút TRẢ X đ (chỉ hiện khi active + chưa trả kỳ này)
                  if (item.active == true && item.displayStatus != 'PAID')
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payment, color: Colors.white, size: 18),
                        label: Text(
                          'Trả tiền',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          _handlePayBill(item);
                        },
                      ),
                    ),
                  if (item.active == true && item.displayStatus != 'PAID') const SizedBox(width: 8),

                  // Nút XÓA
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30), size: 18),
                      label: const Text('Xóa', style: TextStyle(color: Color(0xFFFF3B30), fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF3B30)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDelete(item);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // =============================================
  // [5.11c] HELPER DÙNG CHUNG — Map số ngày → text + màu
  // =============================================
  // Logic traffic-light chuẩn:
  //   < 0      → 🔴 Đỏ   — Quá hạn
  //   == 0     → 🟠 Cam  — Đến hạn hôm nay
  //   1–3 ngày → 🟠 Cam  — Rất cận hạn
  //   4–7 ngày → 🟡 Vàng — Cận hạn
  //   > 7 ngày → 🟢 Xanh — An toàn
  ({String text, Color color}) _resolveExpiry(int days) {
    if (days < 0) {
      return (
      text: '🔴 Quá hạn ${days.abs()} ngày',
      color: const Color(0xFFFF3B30),   // đỏ
      );
    } else if (days == 0) {
      return (
      text: '🟠 Đến hạn hôm nay',
      color: const Color(0xFFFF9500),   // cam
      );
    } else if (days <= 3) {
      return (
      text: '🟠 Còn $days ngày',
      color: const Color(0xFFFF9500),   // cam
      );
    } else if (days <= 7) {
      return (
      text: '🟡 Còn $days ngày',
      color: const Color(0xFFFFCC00),   // vàng
      );
    } else {
      return (
      text: '🟢 Còn $days ngày',
      color: const Color(0xFF4CAF50),   // xanh lá — dùng màu accent của app
      );
    }
  }

  // ----- Helper: Expiry inline — từ statusLabel (OVERDUE case) -----
  // [v2] Thay _buildInlineExpiry(daysUntilDue) — backend không còn trả field này
  Widget _buildInlineExpiryLabel(String label, Color color) {
    return Text(
      '🔴 $label',
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
    );
  }

  // ----- Helper: Expiry inline (cùng hàng ví) — tính local từ nextDueDate -----
  // [v2] Fallback khi không phải OVERDUE: tính ngày còn lại từ nextDueDate
  Widget _buildInlineExpiryFromDate(DateTime nextDueDate) {
    final today = DateTime.now();
    final todayDate   = DateTime(today.year, today.month, today.day);
    final dueDate     = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    final days = dueDate.difference(todayDate).inDays;
    final r = _resolveExpiry(days);
    return Text(r.text, style: TextStyle(color: r.color, fontSize: 12, fontWeight: FontWeight.w500));
  }

  // =============================================
  // [5.11b] HANDLE PAY BILL — Trả tiền hóa đơn
  // =============================================
  Future<void> _handlePayBill(PlannedTransactionResponse item) async {
    final provider = Provider.of<BillProvider>(context, listen: false);
    final success = await provider.payBill(item.id);
    if (!mounted) return;
    if (success) {
      _showSnackBar('Đã thanh toán hóa đơn');
    } else {
      _showSnackBar(provider.errorMessage ?? 'Có lỗi xảy ra', isError: true);
    }
  }

  // =============================================
  // [5.12] NAVIGATE — Mở form tạo mới
  // =============================================
  Future<void> _openCreateForm() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PlannedFormScreen(planType: PlanType.bill),
      ),
    );
    if (result == true && mounted) {
      _showSnackBar('Đã tạo hóa đơn');
    }
  }

  // =============================================
  // [5.13] NAVIGATE — Mở form sửa
  // =============================================
  Future<void> _openEditForm(PlannedTransactionResponse item) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PlannedFormScreen(
          planType: PlanType.bill,
          existing: item,
        ),
      ),
    );
    if (result == true && mounted) {
      _showSnackBar('Đã cập nhật hóa đơn');
    }
  }

  // =============================================
  // [5.14] DIALOG — Xác nhận xóa
  // =============================================
  void _confirmDelete(PlannedTransactionResponse item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        // [TODO i18n] Delete dialog title
        title: const Text('Xóa hóa đơn?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Bạn có chắc muốn xóa "${item.categoryName ?? ''}"?',
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            // [TODO i18n] Dialog cancel
            child: const Text('Không', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<BillProvider>(context, listen: false);
              final success = await provider.delete(item.id);
              if (!mounted) return;
              if (success) {
                _showSnackBar('Đã xóa hóa đơn');
              } else {
                _showSnackBar(provider.errorMessage ?? 'Có lỗi xảy ra', isError: true);
              }
            },
            // [TODO i18n] Dialog delete
            child: const Text('Xóa', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [5.15] HELPER — Hiện SnackBar
  // =============================================
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFFF3B30) : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}