import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/helpers/icon_helper.dart';
import '../providers/wallet_provider.dart';
import '../models/wallet_response.dart';
import 'add_wallet_type_screen.dart';
import 'wallet_detail_screen.dart';
import 'add_basic_wallet_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class WalletListView extends StatefulWidget {
  const WalletListView({super.key});

  @override
  State<WalletListView> createState() => _WalletListViewState();
}
class _WalletListViewState extends State<WalletListView> {
  // Format tiền VNĐ
  String formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount);
  }

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      Provider.of<WalletProvider>(context, listen: false).loadAll();
    });
  }
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Text(
              provider.error!,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (provider.wallets.isEmpty) {
          return _emptyState(context);
        }

        // Phân nhóm ví
        final reportableWallets =
        provider.wallets.where((w) => w.reportable == true).toList();
        final nonReportableWallets =
        provider.wallets.where((w) => w.reportable == false).toList();
        final savingWallets = provider.wallets
            .where((w) => w.goalImageUrl != null && w.goalImageUrl!.isNotEmpty)
            .toList();

        // Tổng số dư các ví reportable
        final totalBalance =
        reportableWallets.fold<double>(0, (sum, w) => sum + w.balance);

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "Ví của tôi",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.green,
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddWalletTypeScreen(), // ✅ đổi ở đây
                ),
              );

              if (result == true) {
                Provider.of<WalletProvider>(context, listen: false).loadAll();
              }
            },
            child: const Icon(Icons.add),
          ),
          body: RefreshIndicator(
            onRefresh: () async => provider.loadAll(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(totalBalance),
                const SizedBox(height: 20),
                if (reportableWallets.isNotEmpty)
                  _walletGroup("Ví tổng", reportableWallets, context),
                if (nonReportableWallets.isNotEmpty)
                  _walletGroup(
                      "Ví không tính tổng", nonReportableWallets, context),
                if (savingWallets.isNotEmpty)
                  _walletGroup("Ví tiết kiệm", savingWallets, context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C853), Color(0xFF64DD17)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Tổng tài sản",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency(total),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletGroup(String title, List<WalletResponse> wallets,
      BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 10),
        ...wallets.map((w) => _walletItem(w, context)),
        const SizedBox(height: 20),
      ],
    );
  }


  Widget _walletItem(WalletResponse wallet, BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () =>
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WalletDetailScreen(wallet: wallet),
            ),
          ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            // ✅ ICON FIX CHUẨN
            IconHelper.buildCircleAvatar(
              iconUrl: wallet.goalImageUrl,
              radius: 26,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.walletName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wallet.currencyCode ?? "VND",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            Text(
              formatCurrency(wallet.balance),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.greenAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _emptyState(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 90,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              "Chưa có ví nào",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Tạo ví để bắt đầu quản lý tài chính",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddBasicWalletScreen(),
                  ),
                );
              },
              child: const Text("Tạo ví"),
            )
          ],
        ),
      ),
    );
  }
}
