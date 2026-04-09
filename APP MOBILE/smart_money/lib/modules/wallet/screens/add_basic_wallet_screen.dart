import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/helpers/icon_helper.dart';
import '../providers/wallet_provider.dart';
import '../models/wallet_request.dart';
import '../../category/screens/icon_picker_screen.dart';

class AddBasicWalletScreen extends StatefulWidget {
  const AddBasicWalletScreen({super.key});

  @override
  State<AddBasicWalletScreen> createState() => _AddBasicWalletScreenState();
}

class CurrencyInputFormatter extends TextInputFormatter {
  final int maxValue = 500000000;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(',', '');
    if (newText.isEmpty) return newValue;

    final number = int.tryParse(newText);
    if (number == null) return oldValue;

    final cappedNumber = number > maxValue ? maxValue : number;
    final formatted = _formatNumber(cappedNumber);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      int position = str.length - i;
      buffer.write(str[i]);
      if (position > 1 && position % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }
}

class _AddBasicWalletScreenState extends State<AddBasicWalletScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();

  bool excludeFromTotal = false;
  final String currency = "VND";
  bool isSaving = false;

  String? _selectedIconUrl;
  String? nameError;
  String? balanceError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
        ),
        centerTitle: true,
        title: const Text("Thêm Ví"),
        actions: [
          TextButton(
            onPressed: _saveWallet, // nút luôn luôn hiển thị
            child: isSaving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text(
              "Lưu",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMainCard(),
          const SizedBox(height: 20),
          _buildSwitchCard(),
        ],
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      decoration: _card(),
      child: Column(
        children: [
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
              decoration: InputDecoration(
                hintText: "Tên ví",
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                errorText: nameError,
              ),
              onChanged: (_) {
                setState(() {
                  nameError = null; // reset lỗi khi user nhập
                });
              },
            ),
          ),
          const Divider(color: Colors.grey, height: 1),
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
              children: const [
                Text("VND", style: TextStyle(color: Colors.white)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
            onTap: null,
          ),
          const Divider(color: Colors.grey, height: 1),
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
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: "0",
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    errorText: balanceError,
                  ),
                  onChanged: (_) {
                    setState(() {
                      balanceError = null; // reset lỗi khi user nhập
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchCard() {
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

  String? _validateBalance(String text) {
    if (text.isEmpty) return "Số tiền không được để trống";
    final raw = text.replaceAll(',', '');
    final value = double.tryParse(raw);
    if (value == null) return "Số tiền không hợp lệ";
    if (value < 0) return "Số tiền không được âm";
    if (value > 500000000) return "Số tiền tối đa là 500,000,000 VND";
    return null;
  }

  Future<void> _saveWallet() async {
    final name = nameController.text.trim();
    final balanceText = balanceController.text;

    setState(() {
      nameError = name.isEmpty ? "Tên ví không được để trống" : null;
      balanceError = _validateBalance(balanceText);
    });

    if (nameError != null || balanceError != null) return;

    final rawText = balanceText.replaceAll(',', '');
    final balance = double.tryParse(rawText) ?? 0;

    setState(() => isSaving = true);

    final provider = Provider.of<WalletProvider>(context, listen: false);

    final request = WalletRequest(
      walletName: name,
      balance: balance,
      currencyCode: currency,
      reportable: !excludeFromTotal,
      goalImageUrl: _selectedIconUrl,
    );

    final success = await provider.createWallet(request);

    setState(() => isSaving = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      _showError(provider.error ?? "Tạo ví thất bại");
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  BoxDecoration _card() => BoxDecoration(
    color: const Color(0xFF1C1C1E),
    borderRadius: BorderRadius.circular(20),
  );
}
