import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/widgets/chart_card.dart';
import 'package:smart_money/widgets/summary_card.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_date_slider.dart';
import 'package:smart_money/modules/transaction/dialogs/date_range_mode_dialog.dart';
import '../modules/notification/providers/notification_provider.dart';
import '../modules/wallet/providers/wallet_provider.dart';
import '../modules/transaction/providers/transaction_provider.dart';
import '../modules/category/providers/category_provider.dart';
import '../modules/transaction/models/report/category_report_dto.dart';
import '../modules/transaction/services/transaction_service.dart';
import '../modules/auth/providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isBalanceHidden = false;
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final ScrollController _dateScrollController = ScrollController();
  
  List<CategoryReportDTO> _categoryReports = [];
  bool _isCategoryLoading = false;

  int? _lastSourceId;
  String? _lastSourceType;
  DateTime? _lastStartDate;
  DateTime? _lastEndDate;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    Future.microtask(() async {
      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn) return;

      // Gọi các thông tin nền tảng song song
      await Future.wait([
        context.read<NotificationProvider>().fetchNotifications(),
        context.read<WalletProvider>().loadAll(),
        context.read<CategoryProvider>().loadByGroup('expense'),
        context.read<TransactionProvider>().initialize(),
      ]);

      if (mounted) _fetchTopCategories();
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<NotificationProvider>().fetchNotifications(),
      context.read<WalletProvider>().loadAll(),
      context.read<TransactionProvider>().refresh(),
      context.read<CategoryProvider>().loadByGroup('expense', forceRefresh: true),
      _fetchTopCategories(),
    ]);
  }

  Future<void> _fetchTopCategories() async {
    if (!mounted) return;
    
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      setState(() {
        _categoryReports = [];
        _isCategoryLoading = false;
      });
      return;
    }

    final transProvider = context.read<TransactionProvider>();
    final source = transProvider.selectedSource;
    final walletId = source.type == 'wallet' ? source.id : null;
    final goalId = source.type == 'saving_goal' ? source.id : null;
    
    DateTime startDate;
    DateTime endDate;

    if (transProvider.isAllMode) {
      startDate = DateTime(2000, 1, 1);
      endDate = DateTime(2099, 12, 31);
    } else if (transProvider.selectedDateRange != null) {
      startDate = transProvider.selectedDateRange!.startDate;
      endDate = transProvider.selectedDateRange!.endDate;
    } else {
      return;
    }

    setState(() => _isCategoryLoading = true);
    
    try {
      final response = await TransactionService.getCategoryReport(
        startDate: startDate,
        endDate: endDate,
        walletId: walletId,
        savingGoalId: goalId,
      );

      if (response.success && response.data != null && mounted) {
        setState(() {
          _categoryReports = response.data!
              .where((c) => c.categoryType == false)
              .toList()
            ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
          _isCategoryLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isCategoryLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transProvider = context.watch<TransactionProvider>();
    final authProvider = context.watch<AuthProvider>();

    // Check if we need to refetch top categories based on provider changes
    final source = transProvider.selectedSource;
    final range = transProvider.selectedDateRange;
    DateTime? start;
    DateTime? end;

    if (transProvider.isAllMode) {
      start = DateTime(2000, 1, 1);
      end = DateTime(2099, 12, 31);
    } else if (range != null) {
      start = range.startDate;
      end = range.endDate;
    }

    if (_lastSourceId != source.id ||
        _lastSourceType != source.type ||
        _lastStartDate != start ||
        _lastEndDate != end) {

      _lastSourceId = source.id;
      _lastSourceType = source.type;
      _lastStartDate = start;
      _lastEndDate = end;

      Future.microtask(() => _fetchTopCategories());
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: Colors.green,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildHeader(context),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildBalanceCard(transProvider),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildWalletSelector(transProvider),
                ),

                const SizedBox(height: 16),
                
                // Filter section giống trang sổ giao dịch
                if (!transProvider.isAllMode && !transProvider.isCustomMode)
                  TransactionDateSlider(scrollController: _dateScrollController),

                if (transProvider.isAllMode)
                  const TransactionSpecialModeLabel(label: 'All the time'),
                if (transProvider.isCustomMode && transProvider.selectedDateRange != null)
                  TransactionSpecialModeLabel(label: transProvider.selectedDateRange!.label),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: const SummaryCard(),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: const ChartCard(),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildTopCategoryCard(authProvider.isLoggedIn),
                ),

                const SizedBox(height: 30),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recent Transactions",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.go('/main', extra: {'index': 1, 'time': DateTime.now().millisecondsSinceEpoch});
                        },
                        child: const Text("View All"),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildRecentTransactions(transProvider),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Smart Money",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined, size: 20),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const DateRangeModeDialog(),
                );
              },
            ),
            Consumer<NotificationProvider>(
              builder: (context, provider, child) {
                final unreadCount = provider.unreadCount;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () {
                        context.push('/notifications');
                      },
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadCount > 9 ? "9+" : unreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                  ],
                );
              },
            ),
          ],
        )
      ],
    );
  }

  Widget _buildBalanceCard(TransactionProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xff4facfe), Color(0xff00f2fe)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff4facfe).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Current Balance",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    isBalanceHidden = !isBalanceHidden;
                  });
                },
                child: Icon(
                  isBalanceHidden ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              )
            ],
          ),
          const SizedBox(height: 15),
          Text(
            isBalanceHidden ? "••••••••" : currencyFormat.format(provider.selectedSource.balance ?? 0.0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (provider.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildWalletSelector(TransactionProvider provider) {
    return InkWell(
      onTap: () async {
        await _showWalletSelectionDialog(context, provider);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Selected Wallet", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(
                    provider.selectedSource.type == 'all' ? "Total Balance" : provider.selectedSource.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCategoryCard(bool isLoggedIn) {
    if (_isCategoryLoading) {
      return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final displayItems = isLoggedIn && _categoryReports.isNotEmpty 
        ? _categoryReports.take(5).toList()
        : _getDefaultCategories();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Opacity(
        opacity: isLoggedIn ? 1.0 : 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Top Spending Categories", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => context.push('/categories/create', extra: false),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text("Create", style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.blueAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayItems.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 16),
              itemBuilder: (context, index) {
                final cat = displayItems[index];
                return Row(
                  children: [
                    _buildCategoryIcon(cat.categoryIcon, false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cat.categoryName,
                        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    ),
                    Text(
                      isLoggedIn ? currencyFormat.format(cat.totalAmount) : "\$0.00",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<CategoryReportDTO> _getDefaultCategories() {
    return const [
      CategoryReportDTO(categoryName: "Food & Beverage", totalAmount: 0, dailyAverage: 0, percentage: 0),
      CategoryReportDTO(categoryName: "Transportation", totalAmount: 0, dailyAverage: 0, percentage: 0),
      CategoryReportDTO(categoryName: "Shopping", totalAmount: 0, dailyAverage: 0, percentage: 0),
    ];
  }

  Future<void> _showWalletSelectionDialog(BuildContext context, TransactionProvider provider) async {
    final filteredSources = provider.sourceItems.where((s) => s.type == 'wallet' || s.type == 'all' || s.type == 'saving_goal').toList();

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Wallet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredSources.length,
                  itemBuilder: (context, index) {
                    final source = filteredSources[index];
                    final bool isTotal = source.type == 'all';
                    final bool isGoal = source.type == 'saving_goal';
                    
                    return ListTile(
                      leading: isTotal 
                        ? const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.account_balance, color: Colors.white, size: 20))
                        : (isGoal 
                            ? const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.savings, color: Colors.white, size: 20))
                            : (source.iconUrl != null 
                                ? Image.network(source.iconUrl!, width: 30, height: 30)
                                : const Icon(Icons.account_balance_wallet))),
                      title: Text(isTotal ? "Total Balance" : source.name),
                      trailing: Text(currencyFormat.format(source.balance ?? 0.0)),
                      selected: provider.selectedSource.id == source.id && provider.selectedSource.type == source.type,
                      onTap: () {
                        provider.selectSource(source);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text("Manage Wallets"),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/wallets'); 
                },
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentTransactions(TransactionProvider provider) {
    if (provider.isLoading && provider.journalGroups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.journalGroups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text("No transactions in this period", style: TextStyle(color: Colors.grey))),
      );
    }

    final filteredTransactions = provider.journalGroups
        .expand((group) => group.transactions)
        .take(5)
        .toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredTransactions.length,
      itemBuilder: (context, index) {
        final tx = filteredTransactions[index];
        final bool isIncome = tx.categoryType;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _buildCategoryIcon(tx.categoryIconUrl, isIncome),
          title: Text(tx.categoryName ?? "Unnamed", style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(DateFormat('MMM dd, yyyy').format(tx.transDate)),
          trailing: Text(
            "${isIncome ? '+' : '-'}${currencyFormat.format(tx.amount)}",
            style: TextStyle(
              color: isIncome ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryIcon(String? iconUrl, bool isIncome) {
    final cloudinaryUrl = IconHelper.buildCloudinaryUrl(iconUrl);
    
    if (cloudinaryUrl != null && cloudinaryUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cloudinaryUrl,
        width: 40,
        height: 40,
        imageBuilder: (context, imageProvider) {
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          );
        },
        placeholder: (_, __) => _buildFallbackIcon(isIncome),
        errorWidget: (_, __, ___) => _buildFallbackIcon(isIncome),
      );
    }
    return _buildFallbackIcon(isIncome);
  }

  Widget _buildFallbackIcon(bool isIncome) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isIncome
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIncome ? Colors.green : Colors.red,
          size: 18,
        ),
      ),
    );
  }
}
