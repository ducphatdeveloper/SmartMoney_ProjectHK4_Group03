// ===========================================================
// [4] RecurringScreen — Màn hình Danh sách giao dịch định kỳ
// ===========================================================
// Layout:
//   • AppBar: nút back + "Giao dịch định kỳ" + Dropdown chọn ví (BottomSheet)
//   • TabBar: ĐANG DIỄN RA / ĐÃ KẾT THÚC
//   • Row: nút [+] tròn xanh → push PlannedFormScreen
//   • TabBarView:
//     - Tab 0: ListView RecurringListItem (active)
//     - Tab 1: ListView RecurringListItem (inactive)
//   • EmptyState: icon 📋 + text hướng dẫn
//
// Flow:
//   1. initState → load danh sách qua RecurringProvider
//   2. User bấm [+] → push PlannedFormScreen(planType: recurring)
//   3. User tap item → mở RecurringDetailSheet (có nút sửa + xóa + toggle)
//   4. Thành công → SnackBar xanh, thất bại → SnackBar đỏ
//
// API liên quan:
//   • GET /api/recurring?active=true|false — load danh sách
//   • POST /api/recurring                  — tạo mới
//   • PUT /api/recurring/{id}              — cập nhật
//   • DELETE /api/recurring/{id}           — xóa
//   • PATCH /api/recurring/{id}/toggle     — bật/tắt active
// ===========================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/planned/enums/plan_type.dart';
import 'package:smart_money/modules/planned/models/planned_transaction_response.dart';
import 'package:smart_money/modules/planned/providers/recurring_provider.dart';
import 'package:smart_money/modules/planned/screens/planned_form_screen.dart';
import 'package:smart_money/modules/planned/widgets/recurring_list_item.dart';
import 'package:smart_money/modules/transaction/services/util_service.dart';
import 'package:smart_money/modules/wallet/models/wallet_response.dart';
import 'package:smart_money/modules/debt/providers/debt_provider.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> with SingleTickerProviderStateMixin {

  // =============================================
  // [4.1] STATE
  // =============================================
  late TabController _tabController; // 2 tab: ĐANG DIỄN RA + ĐÃ KẾT THÚC

  // Danh sách ví (load trực tiếp từ UtilService, không phụ thuộc WalletProvider)
  List<WalletResponse> _wallets = [];
  bool _isLoadingWallets = false;

  // =============================================
  // [4.2] initState — Load dữ liệu lần đầu
  // =============================================
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Khởi tạo TabController

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RecurringProvider>(context, listen: false);
      provider.loadAll(); // Gọi loadAll() thay vì loadRecurring()
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
      debugPrint('❌ [RecurringScreen] Wallet loading error: $e');
    }

    _isLoadingWallets = false;
    if (mounted) setState(() {});
  }

  // =============================================
  // [4.3] dispose
  // =============================================
  @override
  void dispose() {
    _tabController.dispose(); // Dispose TabController
    super.dispose();
  }

  // =============================================
  // [4.4] BUILD
  // =============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // nền đen
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  // =============================================
  // [4.5] APP BAR + TABS — tiêu đề + dropdown chọn ví (BottomSheet)
  // =============================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1C1C1E),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      // [TODO i18n] Hard-coded title string — migrate to AppLocalizations
      // [0b] Giảm fontSize xuống 15 để không bị tràn khi hiển thị cùng wallet dropdown
      title: const Text(
        'Recurring transactions',
        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        // Dropdown chọn ví → BottomSheet
        _buildWalletDropdown(),
      ],
      bottom: TabBar( // Thêm TabBar
        controller: _tabController,
        indicatorColor: const Color(0xFF4CAF50),
        labelColor: const Color(0xFF4CAF50),
        unselectedLabelColor: const Color(0xFF8E8E93),
        tabs: const [
          Tab(text: 'ONGOING'),
          Tab(text: 'ITS OVER'),
        ],
      ),
    );
  }

  // =============================================
  // [4.6] WALLET DROPDOWN — BottomSheet chọn ví với icon + balance
  // =============================================
  // [FIX-2] Đổi từ DropdownButton → GestureDetector + showModalBottomSheet
  // Hiện icon ví + tên + số dư. Không dùng SavingGoal (planned chỉ dùng wallet).
  Widget _buildWalletDropdown() {
    return Consumer<RecurringProvider>(
      builder: (context, recurringProv, _) {
        final wallets = _wallets;
        final selected = recurringProv.selectedWalletId;

        // Tìm tên ví đang chọn để hiển thị trên AppBar
        String displayName = 'All wallets';
        if (selected != null) {
          final found = wallets.where((w) => w.id == selected);
          if (found.isNotEmpty) displayName = found.first.walletName;
        }

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: _isLoadingWallets ? null : () => _showWalletFilterSheet(wallets, recurringProv),
            child: Container(
              // [0c] Thu nhỏ maxWidth từ 200 → 130 để chữ title "Giao dịch định kỳ" hiện đủ
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxWidth: 130),
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
                    const SizedBox(width: 4),
                  ] else ...[
                    // Khi 'Tất cả ví' được chọn (selected == null) hiển thị icon màu xanh lá giống trang transaction
                    const Icon(Icons.account_balance_wallet, color: Color(0xFF4CAF50), size: 16),
                    const SizedBox(width: 4),
                  ],
                  // Tên ví
                  Flexible(
                    child: Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E8E93), size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── BottomSheet danh sách ví — icon + tên + balance ──
  void _showWalletFilterSheet(List<WalletResponse> wallets, RecurringProvider recurringProv) {
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
            // [TODO i18n] Hard-coded BottomSheet header
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose a wallet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
              // [TODO i18n] Hard-coded list tile label
              title: Text(
                'All wallets',
                style: TextStyle(
                  color: recurringProv.selectedWalletId == null ? const Color(0xFF4CAF50) : Colors.white,
                  fontWeight: recurringProv.selectedWalletId == null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: recurringProv.selectedWalletId == null
                  ? const Icon(Icons.check, color: Color(0xFF4CAF50))
                  : null,
              onTap: () {
                recurringProv.setWalletFilter(null);
                Navigator.pop(ctx);
              },
            ),

            // Danh sách wallet (chỉ wallet cơ bản, không SavingGoal)
            ...wallets.map((w) {
              final isSelected = recurringProv.selectedWalletId == w.id;
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
                  recurringProv.setWalletFilter(w.id);
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
  // [4.7] BODY — Nút + TabBarView
  // =============================================
  Widget _buildBody() {
    return Consumer<RecurringProvider>(
      builder: (context, provider, _) {
        // Đang loading
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
                      'Add recurring transactions',
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
                  _buildActiveTab(provider), // Tab "ĐANG DIỄN RA"
                  _buildInactiveTab(provider), // Tab "ĐÃ KẾT THÚC"
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // =============================================
  // [4.8] TAB ĐANG DIỄN RA
  // =============================================
  Widget _buildActiveTab(RecurringProvider provider) {
    final items = provider.activeItems;

    if (provider.errorMessage != null && items.isEmpty) {
      return _buildErrorState(provider.errorMessage!, () => provider.loadAll());
    }

    if (items.isEmpty) {
      return _buildEmptyState('No recurring transactions are currently taking place.\nPress + to add new.');
    }

    // [0a] Dùng ListView thay vì ListView.builder để thêm header label "Các giao dịch cố định"
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        // [0a] Label ghi chú phía trên danh sách
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Fixed transactions',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Danh sách các giao dịch định kỳ
        ...items.map((item) => RecurringListItem(
          item: item,
          onTap: () => _openRecurringDetailSheet(item),
        )),
      ],
    );
  }

  // =============================================
  // [4.9] TAB ĐÃ KẾT THÚC
  // =============================================
  Widget _buildInactiveTab(RecurringProvider provider) {
    final items = provider.inactiveItems;

    if (provider.errorMessage != null && items.isEmpty) {
      return _buildErrorState(provider.errorMessage!, () => provider.loadAll());
    }

    if (items.isEmpty) {
      return _buildEmptyState('No recurring transactions have been completed.');
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return RecurringListItem(
          item: item,
          onTap: () => _openRecurringDetailSheet(item),
        );
      },
    );
  }

  // =============================================
  // [4.10] EMPTY STATE — khi danh sách trống
  // =============================================
  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_repeat, size: 64, color: Color(0xFF8E8E93)),
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
  // [4.11] ERROR STATE — khi có lỗi tải dữ liệu
  // =============================================
  Widget _buildErrorState(String errorMessage, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFFF3B30)),
          const SizedBox(height: 12),
          Text(
            errorMessage,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [4.12] RECURRING DETAIL SHEET — Bottom sheet chi tiết giao dịch định kỳ
  // =============================================
  // [FIX-4] Nút sửa + xóa dời vào đây thay vì hiện trực tiếp trên list item
  void _openRecurringDetailSheet(PlannedTransactionResponse item) {
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
              const SizedBox(height: 16),

              // Icon + Tên category
              IconHelper.buildCircleAvatar(iconUrl: item.categoryIcon, radius: 28),
              const SizedBox(height: 8),
              Text(
                item.categoryName ?? 'Recurring transactions',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),

              // Số tiền
              Text(
                FormatHelper.formatVND(item.amount),
                style: TextStyle(color: amountColor, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Lịch lặp
              if (item.repeatDescription != null) ...[
                Row(
                  children: [
                    const Icon(Icons.repeat, size: 16, color: Color(0xFF8E8E93)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.repeatDescription!,
                        style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Lần tới — dùng nextDueDateLabel nếu có
              if (item.nextDueDateLabel != null) ...[
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF8E8E93)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Next time: ${item.nextDueDateLabel}',
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
                        'Next time: ${FormatHelper.formatDisplayDate(item.nextDueDate!)}',
                        style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Ví
              if (item.walletName != null) ...[
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 16, color: Color(0xFF8E8E93)),
                    const SizedBox(width: 8),
                    Text(
                      item.walletName!,
                      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // =============================================
              // [4.13] SWITCH — Bật/tắt trạng thái active
              // =============================================
              // [FIX] Khi toggle ON → kiểm tra debt nếu planned có liên kết
              // Nếu debt đã finished → hiện lỗi, không cho toggle
              SwitchListTile(
                title: const Text(
                  'In progress', // [TODO i18n]
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                value: item.active ?? false,
                onChanged: (newValue) async {
                  // Bước 1: Nếu đang toggle ON (newValue=true) và planned có debtId
                  // → kiểm tra debt đã hoàn thành chưa
                  if (newValue && item.debtId != null) {
                    // Hiện dialog loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const AlertDialog(
                        backgroundColor: Color(0xFF2C2C2E),
                        content: Row(
                          children: [
                            CircularProgressIndicator(color: Color(0xFF4CAF50)),
                            SizedBox(width: 16),
                            Text('Checking...', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    );

                    // Load debt details để kiểm tra finished
                    final debtProvider = Provider.of<DebtProvider>(context, listen: false);
                    await debtProvider.loadDebts(item.categoryType ?? false);

                    if (!mounted) return;
                    Navigator.pop(context); // Đóng loading dialog

                    // Bước 2: Tìm debt trong danh sách đã load
                    final debtsToCheck = item.categoryType ?? false
                        ? debtProvider.receivableDebts + debtProvider.receivableDone
                        : debtProvider.payableDebts + debtProvider.payableDone;

                    // Kiểm tra xem debt có được tìm thấy và đã hoàn thành không
                    bool debtIsFinished = false;
                    try {
                      final debtFound = debtsToCheck.firstWhere((d) => d.id == item.debtId);
                      debtIsFinished = debtFound.finished;
                    } catch (e) {
                      // Debt không tìm thấy — có thể đã bị xóa hoặc không thuộc account hiện tại
                      // Để người dùng toggle thử, lỗi sẽ được báo từ backend nếu có vấn đề
                    }

                    if (debtIsFinished) {
                      // Debt đã hoàn thành → hiện lỗi, KHÔNG toggle
                      if (!mounted) return;
                      Navigator.pop(ctx); // Đóng bottom sheet
                      _showSnackBar(
                        'The debt has been paid off and cannot be reactivated.',
                        isError: true,
                      );
                      return;
                    }
                  }

                  // Bước 3: Nếu không có debt hoặc debt chưa finished → tiến hành toggle
                  Navigator.pop(ctx); // Đóng bottom sheet trước
                  final provider = Provider.of<RecurringProvider>(context, listen: false);
                  final success = await provider.toggle(item.id);

                  if (!mounted) return;

                  if (success) {
                    // Reload lists so UI updates immediately
                    provider.loadAll();
                    _showSnackBar(provider.successMessage ?? 'Status update successful');
                  } else {
                    _showSnackBar(provider.errorMessage ?? 'An error occurred while updating the status.', isError: true);
                  }
                },
                // `activeColor` deprecated — use `activeThumbColor` (thumb color when active)
                activeThumbColor: const Color(0xFF4CAF50),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.shade700,
                contentPadding: EdgeInsets.zero, // Xóa padding mặc định
              ),
              const SizedBox(height: 16),

              // ── Hàng nút: SỬA + XÓA ──
              Row(
                children: [
                  // Nút SỬA
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF4CAF50), size: 18),
                      label: const Text('Edit', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13)),
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
                  const SizedBox(width: 8),

                  // Nút XÓA
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30), size: 18),
                      label: const Text('Delete', style: TextStyle(color: Color(0xFFFF3B30), fontSize: 13)),
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
  // [4.14] NAVIGATE — Mở form tạo mới
  // =============================================
  Future<void> _openCreateForm() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PlannedFormScreen(planType: PlanType.recurring),
      ),
    );

    // Nếu tạo thành công → provider đã tự reload
    if (result == true && mounted) {
      _showSnackBar('Recurring transactions have been created.');
      // Sau khi tạo thành công, reload lại cả hai tab
      Provider.of<RecurringProvider>(context, listen: false).loadAll();
    }
  }

  // =============================================
  // [4.15] NAVIGATE — Mở form sửa
  // =============================================
  Future<void> _openEditForm(PlannedTransactionResponse item) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PlannedFormScreen(
          planType: PlanType.recurring,
          existing: item,
        ),
      ),
    );

    if (result == true && mounted) {
      _showSnackBar('Regular transaction updates have been made.');
      // Sau khi cập nhật thành công, reload lại cả hai tab
      Provider.of<RecurringProvider>(context, listen: false).loadAll();
    }
  }

  // =============================================
  // [4.16] DIALOG — Xác nhận xóa
  // =============================================
  void _confirmDelete(PlannedTransactionResponse item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text(
          'Delete recurring transactions?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to delete it? "${item.categoryName ?? ''}"?',
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Are not', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<RecurringProvider>(context, listen: false);
              final success = await provider.delete(item.id);

              // [IMPORTANT] Kiểm tra mounted sau await
              if (!mounted) return;

              if (success) {
                _showSnackBar('Recurring transaction deleted');
                // Sau khi xóa thành công, reload lại cả hai tab
                provider.loadAll();
              } else {
                _showSnackBar(provider.errorMessage ?? 'An error occurred.', isError: true);
              }
            },
            child: const Text('Erase', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [4.17] HELPER — Hiện SnackBar
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
