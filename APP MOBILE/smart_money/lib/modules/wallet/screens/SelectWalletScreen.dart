import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/helpers/icon_helper.dart';
import '../models/wallet_response.dart';
import '../providers/wallet_provider.dart';
import 'add_wallet_type_screen.dart';

class SelectWalletScreen extends StatefulWidget {
  const SelectWalletScreen({super.key});

  @override
  State<SelectWalletScreen> createState() => _SelectWalletScreenState();
}

class _SelectWalletScreenState extends State<SelectWalletScreen> {
  int? selectedId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        context.read<WalletProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final wallets = context.watch<WalletProvider>().wallets;

    final total = wallets
        .where((e) => e.reportable == true)
        .fold<double>(0, (sum, e) => sum + (e.balance ?? 0));

    final reportableWallets = wallets
        .where((e) => (e.reportable ?? true) == true)
        .toList();

    final nonReportableWallets = wallets
        .where((e) => (e.reportable ?? true) == false)
        .toList();



    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Select Wallet"),
        centerTitle: true,

        // 🔥 NÚT DONE
        actions: [
          TextButton(
            onPressed: selectedId == null
                ? null
                : () {
              final selected = wallets
                  .firstWhere((e) => e.id == selectedId);
              Navigator.pop(context, selected);
            },
            child: const Text("Xong",
                style: TextStyle(color: Colors.green)),
          )
        ],
      ),
      body: wallets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _totalCard(total),

          const SizedBox(height: 20),

          if (reportableWallets.isNotEmpty)
            _group("VÍ TỔNG", reportableWallets),

          if (nonReportableWallets.isNotEmpty)
            _group("VÍ KHÔNG TÍNH TỔNG", nonReportableWallets),

          const SizedBox(height: 20),

          _actionSection(context, wallets),
        ],
      ),
    );
  }

  // ================= UI =================

  Widget _totalCard(double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueGrey.withOpacity(0.3),
            ),
            child: const Icon(Icons.public, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Tổng Tài Sản",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                formatMoney(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          )

        ],
      ),
    );
  }

  Widget _group(String title, List<WalletResponse> wallets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 10),
        ...wallets.map((e) => _walletItem(e)),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _walletItem(WalletResponse w) {
    final isSelected = selectedId == w.id;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          selectedId = w.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E), // giống WalletList
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: Colors.green, width: 1.5)
              : null,
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

            // ✅ ICON CHUẨN GIỐNG WALLET LIST
            IconHelper.buildCircleAvatar(
              iconUrl: w.goalImageUrl,
              radius: 24,
            ),

            const SizedBox(width: 14),

            // TEXT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.walletName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    w.currencyCode ?? "VND",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            // MONEY
            Text(
              formatMoney(w.balance ?? 0),
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(width: 8),

            // CHECK
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1 : 0,
              child: const Icon(Icons.check, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionSection(BuildContext context, List<WalletResponse> wallets) {
    final isEmpty = wallets.isEmpty;

    return Container(
      decoration: _card(),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.add,
              color: isEmpty ? Colors.blue : Colors.green,
            ),
            title: Text(
              isEmpty ? "Tạo ví đầu tiên" : "Thêm ví",
              style: TextStyle(
                color: isEmpty ? Colors.blue : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddWalletTypeScreen(),
                ),
              );

              if (result == true) {
                context.read<WalletProvider>().loadAll();
              }
            },
          ),
        ],
      ),
    );
  }

  BoxDecoration _card() {
    return BoxDecoration(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(18),
    );
  }

  String formatMoney(double value) {
    return "${value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ",",
    )} đ";
  }
}