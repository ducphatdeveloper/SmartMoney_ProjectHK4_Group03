import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';

class WalletListView extends StatelessWidget {
  const WalletListView({super.key});

  @override
  Widget build(BuildContext context) {

    final provider = Provider.of<WalletProvider>(context);

    if (provider.wallets.isEmpty) {
      return const Center(
        child: Text("Chưa có ví nào"),
      );
    }

    return ListView.builder(
      itemCount: provider.wallets.length,
      itemBuilder: (context, index) {

        final wallet = provider.wallets[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [

              const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  wallet.walletName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              Text(
                "${wallet.balance} ${wallet.currencyCode}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
