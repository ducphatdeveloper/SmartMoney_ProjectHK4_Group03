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
  final int maxValue = 1000000000000;



  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(',', '');
    if (newText.isEmpty) return newValue;

    final number = int.tryParse(newText);
    if (number == null) return oldValue;

    // final cappedNumber = number > maxValue ? maxValue : number;
    final formatted = _formatNumber(number);

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
  bool _hasShownLimitWarning = false;
  bool excludeFromTotal = false;
  final String currency = "VND";
  bool isSaving = false;

  String? _selectedIconUrl;
  String? nameError;
  String? balanceError;

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

  String? _validateName(String text) {
    if (text.isEmpty) return "Tên ví không được để trống";
    if (text.length > 30) return "Tên ví tối đa 30 ký tự";

    final regex = RegExp(r'^[a-zA-Z0-9\sÀ-ỹ]+$');
    if (!regex.hasMatch(text)) {
      return "Không chứa ký tự đặc biệt";
    }

    return null;
  }


  @override
  Widget build(BuildContext context) {
    final isValid = nameError == null && balanceError == null;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Thêm Ví",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: (nameError == null && balanceError == null && !isSaving)
              ? _saveWallet
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: (nameError == null && balanceError == null && !isSaving)
                ? Colors.green
                : Colors.grey.shade800,
          ),
          child: isSaving
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text("Save"),
        ),
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
              inputFormatters: [

                LengthLimitingTextInputFormatter(31),


              ],
              decoration: InputDecoration(
                hintText: "Tên ví",
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                errorText: nameError,
              ),
              onChanged: (value) {
                setState(() {
                  nameError = _validateName(value);
                  // reset lỗi khi user nhập
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
                  onChanged: (value) {
                    _onBalanceChanged(value); // 🔥 format + snackbar

                    setState(() {
                      balanceError = _validateBalance(value); // 🔥 validate realtime
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

  void _onBalanceChanged(String value) {
    final raw = value.replaceAll(',', '');
    int number = int.tryParse(raw) ?? 0;

    const MAX = 1000000000000;

    if (number > MAX) {
      // 🔥 chỉ cảnh báo 1 lần
      if (!_hasShownLimitWarning) {
        _hasShownLimitWarning = true;

        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text("Amount must not exceed 1000 billion"),
              duration: Duration(seconds: 2),
            ),
          );
      }
    } else {
      _hasShownLimitWarning = false;
    }

    final formatted = _formatNumber(number);

    setState(() {
      balanceController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
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
    if (value > 1000000000000) return "Số tiền tối đa là 1000 Tỷ VND";
    return null;
  }

  Future<void> _saveWallet() async {
    final name = nameController.text.trim();
    final balanceText = balanceController.text;

    setState(() {
      nameError = _validateName(name);

      balanceError = _validateBalance(balanceText);
    });

    if (nameError != null || balanceError != null) {
      // 🔥 SHOW THÔNG BÁO
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(balanceError ?? nameError!),
          ),
        );
      return;
    }

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
