import 'package:flutter/material.dart';

class WalletPicker extends StatelessWidget {
  final String title;
  final String walletName;
  final VoidCallback onTap;

  const WalletPicker({
    super.key,
    required this.title,
    required this.walletName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(walletName),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
