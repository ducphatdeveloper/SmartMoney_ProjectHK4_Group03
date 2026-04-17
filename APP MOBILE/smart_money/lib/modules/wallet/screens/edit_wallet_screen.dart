import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool notification = true;
  bool excludeFromTotal = false;
  String currency = "VND";
  bool isSaving = false;
  // final name = nameController.text.trim();
  late final name = nameController.text.trim();
  String? _selectedIconUrl;

  String? nameError;
  String? balanceError;

  String? _validateName(String text) {
    if (text.isEmpty) return "Tên ví không được để trống";
    if (text.length > 30) return "Tên ví tối đa 30 ký tự";
    return null;
  }


  @override
  void initState() {
    super.initState();

    notification = widget.wallet.notified ?? true;
    nameController = TextEditingController(text: widget.wallet.walletName);
    balanceController =
        TextEditingController(text: _formatNumber(widget.wallet.balance));
    // ✅ PHẢI đặt SAU khi init controller
    _lastValidText = balanceController.text;
    excludeFromTotal = !(widget.wallet.reportable ?? true);
    _selectedIconUrl = widget.wallet.goalImageUrl;
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
          "Chỉnh sửa ví",
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
              ? _save
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
              : const Text("Lưu"),
        ),
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
              decoration: InputDecoration(
                hintText: "Tên ví",
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                errorText: nameError,
              ),
              inputFormatters: [

                LengthLimitingTextInputFormatter(31),


              ],
              onChanged: (value) {
                // tránh lỗi Telex
                if (nameController.value.composing.isValid) return;

                setState(() {
                  nameError = _validateName(value);
                });
              },

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
              ],
            ),
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
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // 🔥 QUAN TRỌNG
                  ],
                  onChanged: _onBalanceChanged,
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
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchCard() {
    return Column(
      children: [
        // Bật thông báo
        Container(
          decoration: _card(),
          child: SwitchListTile(
            title: const Text(
              "Bật thông báo",
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              "Nhận thông báo khi ví có giao dịch",
              style: TextStyle(color: Colors.grey),
            ),
            value: notification,
            onChanged: (v) {
              setState(() {
                notification = v;
              });
            },
          ),
        ),
        const SizedBox(height: 10),
        // Không tính vào tổng
        Container(
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
        ),
      ],
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

  bool _hasShownLimitWarning = false;
  String _lastValidText = '';


  void _onBalanceChanged(String value) {
    final raw = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (raw.isEmpty) {
      setState(() {
        _lastValidText = '';
        balanceController.text = '';
        balanceError = "Số tiền không được để trống";
      });
      return;
    }

    int number = int.parse(raw);
    const MAX = 1000000000000;

    // ❌ nếu vượt → rollback
    if (number > MAX) {
      if (!_hasShownLimitWarning) {
        _hasShownLimitWarning = true;

        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text("Số tiền không được vượt quá 1000 tỷ"),
            ),
          );
      }

      // 🔥 rollback về giá trị hợp lệ trước đó
      balanceController.value = TextEditingValue(
        text: _lastValidText,
        selection: TextSelection.collapsed(offset: _lastValidText.length),
      );

      return;
    }

    _hasShownLimitWarning = false;

    final formatted = _formatNumber(number.toDouble());

    // 🔥 lưu lại giá trị hợp lệ
    _lastValidText = formatted;

    setState(() {
      balanceController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );

      balanceError = null;
    });
  }








  // ================= VALIDATION =================

  String? _validateBalance(String text) {
    if (text.isEmpty) return "Số tiền không được để trống";

    final raw = text.replaceAll('.', '');

    final value = double.tryParse(raw);

    if (value == null) return "Số tiền không hợp lệ";
    if (value < 0) return "Số tiền không được âm";
    if (value > 1000000000000) {
      return "Số tiền tối đa là 1000 Tỷ VND";
    }

    return null;
  }


  // ================= ACTION =================

  Future<void> _save() async {
    final name = nameController.text.trim();

    setState(() {
      nameError = _validateName(name);
      balanceError = _validateBalance(balanceController.text);
    });

    if (nameError != null || balanceError != null) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(nameError ?? balanceError!),
          ),
        );
      return;
    }

    setState(() => isSaving = true);

    final provider = Provider.of<WalletProvider>(context, listen: false);

    final rawBalance = balanceController.text.replaceAll('.', '');

    final request = WalletRequest(
      walletName: name,
      balance: double.tryParse(rawBalance) ?? 0,
      currencyCode: currency,
      reportable: !excludeFromTotal,
      notified: notification,
      goalImageUrl: _selectedIconUrl,
    );

    final success = await provider.updateWallet(widget.wallet.id, request);

    setState(() => isSaving = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      _showError(provider.error ?? "Cập nhật ví thất bại");
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
}
