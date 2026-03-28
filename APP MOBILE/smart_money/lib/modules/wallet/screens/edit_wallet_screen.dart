import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/wallet/models/wallet_request.dart';
import '../../../core/helpers/icon_helper.dart';
import '../models/wallet_response.dart';
import '../providers/wallet_provider.dart';
import '../../category/screens/icon_picker_screen.dart';

class EditWalletScreen extends StatefulWidget {
  final WalletResponse wallet;

  const EditWalletScreen({super.key, required this.wallet});

  @override
  State<EditWalletScreen> createState() => _EditWalletScreenState();
}

class _EditWalletScreenState extends State<EditWalletScreen> {
  late TextEditingController nameController;
  late TextEditingController balanceController;

  bool excludeFromTotal = false;
  String currency = "VND";
  bool isSaving = false;

  String? _selectedIconUrl;

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(text: widget.wallet.walletName);

    balanceController =
        TextEditingController(text: _formatNumber(widget.wallet.balance));

    currency = widget.wallet.currencyCode ?? "VND";
    excludeFromTotal = !(widget.wallet.reportable ?? true);
    _selectedIconUrl = widget.wallet.goalImageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final canSave = nameController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Chỉnh sửa ví"),
        actions: [
          TextButton(
            onPressed: (!canSave || isSaving) ? null : _save,
            child: isSaving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(
              "Lưu",
              style: TextStyle(
                color: canSave ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _mainCard(),
          const SizedBox(height: 20),
          _switchCard(),
        ],
      ),
    );
  }

  // ================= UI =================

  Widget _mainCard() {
    return Container(
      decoration: _card(),
      child: Column(
        children: [
          /// NAME + ICON
          ListTile(
            leading: GestureDetector(
              onTap: _openIconPicker,
              child: IconHelper.buildCircleAvatar(
                iconUrl: _selectedIconUrl,
                radius: 26,
                backgroundColor: Colors.orange.withOpacity(0.2),
              ),
            ),
            title: TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Tên ví",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          const Divider(color: Colors.grey, height: 1),

          /// CURRENCY
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                "https://flagcdn.com/w40/vn.png",
                width: 28,
                height: 20,
                fit: BoxFit.cover,
              ),
            ),
            title: const Text(
              "Đơn vị tiền tệ",
              style: TextStyle(color: Colors.grey),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(currency, style: const TextStyle(color: Colors.white)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            onTap: _pickCurrency,
          ),

          const Divider(color: Colors.grey, height: 1),

          /// BALANCE
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Số tiền hiện có",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: balanceController,
                  keyboardType: TextInputType.number,
                  onChanged: _onMoneyChanged,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: "0",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchCard() {
    return Container(
      decoration: _card(),
      child: SwitchListTile(
        title: const Text(
          "Không tính vào tổng",
          style: TextStyle(color: Colors.white),
        ),
        subtitle: const Text(
          'Bỏ qua ví này khỏi "Tổng"',
          style: TextStyle(color: Colors.grey),
        ),
        value: excludeFromTotal,
        onChanged: (v) {
          setState(() {
            excludeFromTotal = v;
          });
        },
      ),
    );
  }

  BoxDecoration _card() => BoxDecoration(
    color: const Color(0xFF1C1C1E),
    borderRadius: BorderRadius.circular(20),
  );

  // ================= MONEY FORMAT =================

  String _formatNumber(double amount) {
    String value = amount.toInt().toString();

    return value.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
  }

  void _onMoneyChanged(String value) {
    String digits = value.replaceAll('.', '');

    if (digits.isEmpty) return;

    final formatted = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );

    balanceController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  // ================= ACTION =================

  Future<void> _save() async {
    setState(() => isSaving = true);

    final provider =
    Provider.of<WalletProvider>(context, listen: false);

    final rawBalance =
    balanceController.text.replaceAll('.', '');

    final request = WalletRequest(
      walletName: nameController.text,
      balance: double.tryParse(rawBalance) ?? 0,
      currencyCode: currency,
      reportable: !excludeFromTotal,
      goalImageUrl: _selectedIconUrl,
    );

    final success = await provider.updateWallet(
      widget.wallet.id,
      request,
    );

    setState(() => isSaving = false);

    if (success) {
      Navigator.pop(context, true);
    }
  }

  void _openIconPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IconPickerScreen()),
    );

    if (result != null && mounted) {
      setState(() => _selectedIconUrl = result.url);
    }
  }

  void _pickCurrency() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("VND", style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => currency = "VND");
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("USD", style: TextStyle(color: Colors.white)),
              onTap: () {
                setState(() => currency = "USD");
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}