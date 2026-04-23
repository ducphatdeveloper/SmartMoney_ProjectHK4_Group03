import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/helpers/icon_helper.dart';
import '../../../modules/transaction/providers/transaction_provider.dart';
import '../../budget/screens/budget_screens.dart';
import '../models/wallet_response.dart';
import '../models/transfer_request.dart';
import '../models/wallet_delete_preview_response.dart';
import '../providers/wallet_provider.dart';
import 'edit_wallet_screen.dart';

class WalletDetailScreen extends StatefulWidget {
  final WalletResponse wallet;

  const WalletDetailScreen({super.key, required this.wallet});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  late bool excludeFromTotal;
  bool notification = false;
  WalletResponse? _wallet;
  bool _hasViewedBudgets = false; // Track xem user đã xem ngân sách chưa

  @override
  void initState() {
    super.initState();
    _wallet = widget.wallet;
    excludeFromTotal = !(widget.wallet.reportable ?? true);
    _loadWalletDetail();
  }

  Future<void> _loadWalletDetail() async {
    try {
      final provider = Provider.of<WalletProvider>(context, listen: false);
      final freshWallet = await provider.getWalletDetail(widget.wallet.id);
      if (freshWallet != null) {
        setState(() {
          _wallet = freshWallet;
        });
      }
    } catch (e) {
      // Nếu lỗi, dùng wallet cũ
      setState(() {
        _wallet = widget.wallet;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = _wallet ?? widget.wallet;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditWalletScreen(wallet: wallet),
                ),
              );

              if (result == true) {
                Provider.of<WalletProvider>(context, listen: false).loadAll(context);
                Navigator.pop(context);
              }
            },
          ),
        ],

      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _mainCard(wallet),
          const SizedBox(height: 20),
          const SizedBox(height: 30),
          _deleteButton(context),
        ],
      ),
    );
  }

  // ================= FORMAT MONEY =================

  String formatVND(double amount) {
    String value = amount.toInt().toString();

    final result = value.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );

    return "$result đ";
  }

  // ================= UI =================

  Widget _mainCard(WalletResponse wallet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2C2C2E),
            Color(0xFF1C1C1E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          /// ICON + NAME
          Row(
            children: [
              IconHelper.buildCircleAvatar(
                iconUrl: wallet.goalImageUrl,
                radius: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  wallet.walletName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// BALANCE
          Text(
            formatVND(wallet.balance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            "Current balance",
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 20),

          const Divider(color: Colors.grey, height: 1),

          const SizedBox(height: 12),

          /// CURRENCY
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.attach_money, color: Colors.grey, size: 18),
              SizedBox(width: 6),
              Text(
                "Vietnamese Dong",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deleteButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1C1C1E),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onPressed: () => _confirmDelete(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.delete, color: Colors.red),
          SizedBox(width: 8),
          Text(
            "Delete Wallet",
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ],
      ),
    );
  }


  // ================= ACTION =================

  void _confirmDelete(BuildContext context) {
    // Nếu user chưa xem ngân sách, hiển thị dialog với link xem ngân sách
    if (!_hasViewedBudgets) {
      _showFirstDeleteDialog(context);
    } else {
      // Nếu đã xem ngân sách, check số dư và hiển thị dialog phù hợp
      _checkBalanceAndShowDialog(context);
    }
  }

  void _showFirstDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Delete Wallet"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Are you sure you want to delete this wallet?",
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              "If deleted, all budgets related to this wallet may be affected.",
              style: TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                // KHÔNG set _hasViewedBudgets = true, chỉ navigate xem ngân sách
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BudgetScreen(
                      initialWallet: widget.wallet,
                    ),
                  ),
                );
              },
              child: const Text(
                "View related budgets",
                style: TextStyle(
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _hasViewedBudgets = true;
              });
              // Sau khi bấm Delete lần 2 ở dialog này, mới check số dư
              _checkBalanceAndShowDialog(context);
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkBalanceAndShowDialog(BuildContext context) async {
    // Lưu context trước khi await
    if (!context.mounted) return;

    // Hiển thị loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Colors.black,
        content: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    // Lấy preview trước khi xóa
    final provider = Provider.of<WalletProvider>(context, listen: false);
    final preview = await provider.getDeletePreview(widget.wallet.id);

    // Đóng loading dialog
    if (!context.mounted) return;
    Navigator.pop(context);

    if (preview == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot get wallet information')),
        );
      }
      return;
    }

    // Nếu số dư > 0, hiển thị dialog chuyển tiền
    if (preview.currentBalance > 0) {
      if (context.mounted) {
        _showTransferDialog(context, preview);
      }
    } else {
      // Nếu số dư = 0, hiển thị dialog xác nhận xóa
      if (context.mounted) {
        _showDeleteConfirmDialog(context, preview);
      }
    }
  }

  void _showDeleteConfirmDialog(
      BuildContext context, WalletDeletePreviewResponse preview) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Delete Wallet"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Are you sure you want to delete wallet ${preview.wallet.walletName}?",
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "Balance: ${formatVND(preview.currentBalance)}",
              style: const TextStyle(color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              "Related budgets: ${preview.relatedBudgets.length}",
              style: const TextStyle(color: Colors.orange),
            ),
            const SizedBox(height: 8),
            Text(
              "Related transactions: ${preview.transactionCount}",
              style: const TextStyle(color: Colors.orange),
            ),
            const SizedBox(height: 12),
            const Text(
              "If deleted, all related budgets will be affected.",
              style: TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BudgetScreen(
                      initialWallet: widget.wallet,
                    ),
                  ),
                );
              },
              child: const Text(
                "View related budgets",
                style: TextStyle(
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final provider =
                  Provider.of<WalletProvider>(context, listen: false);

              await provider.deleteWallet(context, widget.wallet.id);

              if (context.mounted) {
                // Reload danh sách ví sau khi xóa thành công
                await provider.loadAll(context);
                context.read<TransactionProvider>().refreshSourceItems(context);
                Navigator.pop(context);
                Navigator.pop(context, true);
              }
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransferDialog(
      BuildContext context, WalletDeletePreviewResponse preview) {
    int? selectedWalletId;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.black,
          title: const Text("Transfer money before deletion"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Wallet ${preview.wallet.walletName} has ${formatVND(preview.currentBalance)}",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  "You need to transfer all balance to another wallet before deletion.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Select wallet to transfer:",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (preview.otherWallets.isEmpty)
                  const Text(
                    "No other wallet to transfer",
                    style: TextStyle(color: Colors.redAccent),
                  )
                else
                  ...preview.otherWallets.map((wallet) {
                    return RadioListTile<int>(
                      title: Text(
                        wallet.walletName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "Balance: ${formatVND(wallet.balance)}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      value: wallet.id,
                      groupValue: selectedWalletId,
                      onChanged: (value) {
                        setState(() {
                          selectedWalletId = value;
                        });
                      },
                      activeColor: Colors.blue,
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: selectedWalletId == null
                  ? null
                  : () async {
                      // Transfer money
                      final provider =
                          Provider.of<WalletProvider>(context, listen: false);
                      
                      final request = TransferRequest(
                        fromWalletId: widget.wallet.id,
                        toWalletId: selectedWalletId!,
                        amount: preview.currentBalance,
                      );

                      final success = await provider.transferMoney(context, request);

                      if (context.mounted) {
                        Navigator.pop(context);

                        if (success) {
                          // Reload danh sách ví sau khi chuyển tiền thành công
                          await provider.loadAll(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Transfer money and delete wallet successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          // Navigate back về màn hình danh sách ví vì ví đã bị xóa
                          Navigator.pop(context, true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Transfer money failed'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: const Text(
                "Transfer",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
