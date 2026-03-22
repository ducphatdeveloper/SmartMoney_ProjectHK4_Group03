import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wallet_provider.dart';

class AddBasicWalletScreen extends StatefulWidget {
  const AddBasicWalletScreen({super.key});

  @override
  State<AddBasicWalletScreen> createState() => _AddBasicWalletScreenState();
}

class _AddBasicWalletScreenState extends State<AddBasicWalletScreen> {

  final TextEditingController nameController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();

  IconData selectedIcon = Icons.account_balance_wallet;
  bool excludeFromTotal = false;
  String currency = "VND";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tạo ví cơ bản"),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () async {

              final provider =
              Provider.of<WalletProvider>(context, listen: false);

              const token = "YOUR_TOKEN";

              await provider.addWallet(
                {
                  'walletName': nameController.text,
                  'balance': double.tryParse(balanceController.text) ?? 0,
                  'currencyCode': currency,
                  'reportable': !excludeFromTotal,
                },
                token,
              );

              Navigator.pop(context);
            },
            child: const Text(
              "LƯU",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _nameAndIcon(),
          const SizedBox(height: 16),
          _currencyPicker(),
          const SizedBox(height: 16),
          _balanceInput(),
          const SizedBox(height: 16),
          _excludeFromTotalSwitch(),
        ],
      ),
    );
  }

  Widget _nameAndIcon() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showIconPicker,
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.blue.withOpacity(0.15),
              child: Icon(selectedIcon, color: Colors.blue),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Tên ví",
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _cardDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currency,
          items: const [
            DropdownMenuItem(value: "VND", child: Text("VND - Việt Nam Đồng")),
            DropdownMenuItem(value: "USD", child: Text("USD - Đô la Mỹ")),
            DropdownMenuItem(value: "EUR", child: Text("EUR - Euro")),
          ],
          onChanged: (value) {
            setState(() {
              currency = value!;
            });
          },
        ),
      ),
    );
  }

  Widget _balanceInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _cardDecoration(),
      child: TextField(
        controller: balanceController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: "Số tiền hiện có",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _excludeFromTotalSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _cardDecoration(),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text("Không tính vào tổng cộng"),
        value: excludeFromTotal,
        onChanged: (value) {
          setState(() {
            excludeFromTotal = value;
          });
        },
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(16),
    );
  }

  void _showIconPicker() {
    final icons = [
      Icons.account_balance_wallet,
      Icons.credit_card,
      Icons.money,
      Icons.savings,
      Icons.shopping_bag,
      Icons.home,
      Icons.directions_car,
    ];

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: icons.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
          ),
          itemBuilder: (_, index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedIcon = icons[index];
                });
                Navigator.pop(context);
              },
              child: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.15),
                child: Icon(icons[index], color: Colors.blue),
              ),
            );
          },
        );
      },
    );
  }
}
