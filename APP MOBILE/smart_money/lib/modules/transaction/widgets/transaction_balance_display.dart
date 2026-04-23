import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';

/// Widget hiển thị số dư ví hiện tại (căn giữa)
class TransactionBalanceDisplay extends StatelessWidget {
  const TransactionBalanceDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final balance = provider.selectedSource.balance ?? 0.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.black87,
          child: Column(
            children: [
              const Text(
                'Balance',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                FormatHelper.formatVND(balance),
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 16,
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

