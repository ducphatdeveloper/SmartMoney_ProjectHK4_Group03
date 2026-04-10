// modules/transaction/screens/transaction_list_screen.dart
// Màn hình danh sách sổ giao dịch (Nhật ký + Nhóm)
// Dựa theo Money Lover design + yêu cầu uigiaodich.txt

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_app_bar.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_balance_display.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_date_slider.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_summary.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_list.dart';
import 'package:smart_money/modules/transaction/screens/transaction_search_screen.dart';
import 'package:smart_money/modules/transaction/screens/transaction_report_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final ScrollController _dateScrollController = ScrollController();

  /// true → hiện báo cáo tóm tắt | false → hiện danh sách giao dịch
  bool _isReportMode = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<TransactionProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TransactionAppBar(
        onSearchPressed: () {
          // Mở màn hình tìm kiếm giao dịch
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TransactionSearchScreen()),
          );
        },
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.journalGroups.isEmpty && provider.groupedCategories.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null && provider.journalGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 12),
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // ── ALWAYS: Số dư ví ────────────────────────────────
              const TransactionBalanceDisplay(),

              // ── ALWAYS: Thanh trượt ngày ─────────────────────────
              if (!provider.isAllMode && !provider.isCustomMode)
                TransactionDateSlider(scrollController: _dateScrollController),

              if (provider.isAllMode)
                const TransactionSpecialModeLabel(label: 'All the time'),
              if (provider.isCustomMode && provider.selectedDateRange != null)
                TransactionSpecialModeLabel(
                    label: provider.selectedDateRange!.label),

              // ── BODY: Chuyển đổi List ↔ Report ──────────────────
              Expanded(
                child: _isReportMode
                    ? TransactionReportPanel(
                        onClose: () => setState(() => _isReportMode = false),
                      )
                    : RefreshIndicator(
                        onRefresh: () => provider.refresh(),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            children: [
                              // Tóm tắt thu chi
                              const TransactionSummary(),

                              // Nút xem báo cáo
                              TransactionReportButton(
                                onTap: () => setState(() => _isReportMode = true),
                              ),

                              // Loading indicator
                              if (provider.isLoading)
                                const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),

                              // Danh sách giao dịch
                              const TransactionListView(),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
