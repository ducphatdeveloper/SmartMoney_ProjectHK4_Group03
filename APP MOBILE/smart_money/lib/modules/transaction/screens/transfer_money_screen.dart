// modules/transaction/screens/transfer_money_screen.dart
// Màn hình chuyển tiền đến ví khác

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/wallet/providers/wallet_provider.dart';
import 'package:smart_money/modules/wallet/models/wallet_response.dart';
import 'package:smart_money/modules/saving_goal/providers/saving_goal_provider.dart';
import 'package:smart_money/modules/saving_goal/models/saving_goal_response.dart';
import 'package:smart_money/modules/transaction/services/transaction_service.dart';
import 'package:smart_money/modules/transaction/models/request/transaction_request.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/budget/providers/budget_provider.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';

/// Model đại diện nguồn chuyển tiền (Wallet hoặc SavingGoal)
class TransferSource {
  final int id; // ID của nguồn
  final String name; // Tên nguồn
  final double balance; // Số dư
  final String type; // Loại: 'wallet' hoặc 'saving_goal'
  final String? iconUrl; // URL icon

  TransferSource({
    required this.id,
    required this.name,
    required this.balance,
    required this.type,
    this.iconUrl,
  });

  /// Chuyển từ WalletResponse sang TransferSource
  factory TransferSource.fromWallet(WalletResponse wallet) {
    return TransferSource(
      id: wallet.id,
      name: wallet.walletName,
      balance: wallet.balance,
      type: 'wallet',
      iconUrl: wallet.goalImageUrl,
    );
  }

  /// Chuyển từ SavingGoalResponse sang TransferSource
  factory TransferSource.fromSavingGoal(SavingGoalResponse goal) {
    return TransferSource(
      id: goal.id,
      name: goal.goalName,
      balance: goal.currentAmount,
      type: 'saving_goal',
      iconUrl: goal.imageUrl,
    );
  }
}

/// Màn hình chuyển tiền đến ví khác
class TransferMoneyScreen extends StatefulWidget {
  const TransferMoneyScreen({super.key});

  @override
  State<TransferMoneyScreen> createState() => _TransferMoneyScreenState();
}

class _TransferMoneyScreenState extends State<TransferMoneyScreen> {
  // Bước 0: Khai báo controller và state
  final TextEditingController _amountController = TextEditingController(); // Controller nhập số tiền
  final TextEditingController _noteController = TextEditingController(); // Controller nhập ghi chú
  final TextEditingController _fromController = TextEditingController(); // Controller hiển thị nguồn chuyển
  final TextEditingController _toController = TextEditingController(); // Controller hiển thị đích đến
  final TextEditingController _feeController = TextEditingController(); // Controller nhập phí chuyển khoản

  TransferSource? _fromSource; // Nguồn chuyển tiền
  TransferSource? _toSource; // Đích đến
  DateTime? _selectedDate; // Ngày giao dịch
  bool _isProcessing = false; // Đang xử lý chuyển tiền

  List<TransferSource> _availableSources = []; // Danh sách nguồn có thể chọn

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now(); // Mặc định ngày hôm nay
    _loadAvailableSources(); // Bước 1: Load danh sách nguồn
  }

  @override
  void dispose() {
    // Bước 0.1: Dispose controller
    _amountController.dispose();
    _noteController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  /// [1] Load danh sách wallet và saving goal có thể chuyển tiền
  Future<void> _loadAvailableSources() async {
    final walletProvider = context.read<WalletProvider>();
    final savingGoalProvider = context.read<SavingGoalProvider>();

    // Bước 1.1: Load wallets
    await walletProvider.loadAll(context);
    
    // Bước 1.2: Load saving goals (chỉ lấy chưa finished)
    await savingGoalProvider.loadGoals(false, forceRefresh: true);

    // Bước 1.3: Tạo danh sách nguồn chuyển tiền
    setState(() {
      _availableSources = [
        // Thêm wallets
        ...walletProvider.wallets.map((w) => TransferSource.fromWallet(w)),
        // Thêm saving goals
        ...savingGoalProvider.goals.map((g) => TransferSource.fromSavingGoal(g)),
      ];
    });
  }

  /// [2] Hiển thị dialog chọn nguồn chuyển tiền
  Future<void> _showSourcePicker({required bool isFrom}) async {
    final selected = await showModalBottomSheet<TransferSource>(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return ListView.builder(
          itemCount: _availableSources.length,
          itemBuilder: (context, index) {
            final source = _availableSources[index];
            
            // Bước 2.1: Nếu đang chọn From, loại trừ To đã chọn
            if (isFrom && _toSource != null && source.id == _toSource!.id && source.type == _toSource!.type) {
              return const SizedBox.shrink();
            }
            
            // Bước 2.2: Nếu đang chọn To, loại trừ From đã chọn
            if (!isFrom && _fromSource != null && source.id == _fromSource!.id && source.type == _fromSource!.type) {
              return const SizedBox.shrink();
            }

            return ListTile(
              leading: _buildSourceIcon(source),
              title: Text(
                source.name,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                FormatHelper.formatVND(source.balance),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              onTap: () => Navigator.pop(context, source),
            );
          },
        );
      },
    );

    // Bước 2.3: Cập nhật state khi chọn
    if (selected != null) {
      setState(() {
        if (isFrom) {
          _fromSource = selected;
          _fromController.text = selected.name;
        } else {
          _toSource = selected;
          _toController.text = selected.name;
        }
      });
    }
  }

  /// [3] Build icon cho nguồn chuyển tiền
  Widget _buildSourceIcon(TransferSource source) {
    final cloudinaryUrl = IconHelper.buildCloudinaryUrl(source.iconUrl);
    
    // Bước 3.1: Nếu có URL icon, load từ Cloudinary
    if (cloudinaryUrl != null && cloudinaryUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cloudinaryUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildDefaultIcon(source),
        errorWidget: (context, url, error) => _buildDefaultIcon(source),
      );
    }
    
    return _buildDefaultIcon(source);
  }

  /// [3.2] Build icon mặc định khi không có URL
  Widget _buildDefaultIcon(TransferSource source) {
    IconData iconData;
    Color bgColor;

    // Bước 3.2.1: Chọn icon theo type
    if (source.type == 'saving_goal') {
      iconData = Icons.savings;
      bgColor = Colors.orange.shade400;
    } else {
      iconData = Icons.account_balance_wallet;
      bgColor = Colors.green.shade400;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: Colors.white, size: 22),
    );
  }

  /// [4] Chọn ngày giao dịch (không cho chọn quá khứ)
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, 1); // Bắt đầu từ tháng hiện tại
    
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 10),
    );

    // Bước 4.1: Cập nhật state khi chọn ngày
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// [5] Xử lý chuyển tiền - tạo 3 transaction (chuẩn kế toán)
  Future<void> _handleTransfer() async {
    // Bước 5.1: Validate From
    if (_fromSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select source')),
      );
      return;
    }

    // Bước 5.2: Validate To
    if (_toSource == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select destination')),
      );
      return;
    }

    // Bước 5.3: Validate không cùng nguồn
    if (_fromSource!.id == _toSource!.id && _fromSource!.type == _toSource!.type) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot transfer to the same source')),
      );
      return;
    }

    // Bước 5.4: Validate số tiền
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter amount')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount')),
      );
      return;
    }

    // Bước 5.5: Validate số dư
    if (amount > _fromSource!.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }

    // Bước 5.6: Validate ngày
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date')),
      );
      return;
    }

    // Bước 5.7: Parse phí chuyển khoản (mặc định 0)
    final fee = _feeController.text.isEmpty ? 0.0 : double.tryParse(_feeController.text) ?? 0.0;
    if (fee < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee cannot be negative')),
      );
      return;
    }

    // Bước 5.8: Validate số dư đủ cho số tiền chuyển + phí
    if (amount + fee > _fromSource!.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance (including fee)')),
      );
      return;
    }

    // [FIX-TRANSFER-SAVINGGOAL] Check savinggoal target limit trước khi chuyển tiền
    // Nếu _toSource là savinggoal → check xem amount có vượt target không
    if (_toSource!.type == 'saving_goal') {
      final remaining = _toSource!.balance; // target - currentAmount
      if (amount > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer amount exceeds target. Amount that can still be deposited: ${FormatHelper.formatVND(remaining)}')),
        );
        return;
      }
    }

    // [FIX-TRANSFER-WALLET-MAX] Check wallet balance sau khi transfer có vượt 1000 tỷ không
    // Nếu _toSource là wallet → check xem balance + amount > 1000 tỷ không
    if (_toSource!.type == 'wallet') {
      final newBalance = _toSource!.balance + amount;
      if (newBalance > 1000000000000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer amount would exceed wallet maximum limit of 1,000 billion VND')),
        );
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Bước 5.9: Tạo Transaction 1 - Fee (nếu có phí) - TRƯỚC TIÊN
      // Phí giao dịch được trừ trước
      if (fee > 0) {
        final feeRequest = TransactionRequest(
          amount: fee.toString(),
          categoryId: 13, // Transfer Out (phí cũng là chi chuyển khoản)
          note: "Transfer fee",
          transDate: _selectedDate!,
          reportable: true,
          sourceType: 1, // manual
          walletId: _fromSource!.type == 'wallet' ? _fromSource!.id : null,
          goalId: _fromSource!.type == 'saving_goal' ? _fromSource!.id : null,
        );

        final response1 = await TransactionService.create(feeRequest);
        if (!response1.success) {
          throw Exception(response1.message ?? 'Failed to create fee transaction');
        }
      }

      // Bước 5.10: Tạo Transaction 2 - Transfer Out (category 13) cho _fromSource
      // Số tiền chuyển đi = amount (không bao gồm phí)
      final transferOutRequest = TransactionRequest(
        amount: amount.toString(), // Đổi sang String để tránh precision error
        categoryId: 13, // Transfer Out
        note: _noteController.text,
        transDate: _selectedDate!,
        reportable: true,
        sourceType: 1, // manual
        walletId: _fromSource!.type == 'wallet' ? _fromSource!.id : null,
        goalId: _fromSource!.type == 'saving_goal' ? _fromSource!.id : null,
      );

      final response2 = await TransactionService.create(transferOutRequest);
      if (!response2.success) {
        throw Exception(response2.message ?? 'Failed to create transfer out transaction');
      }

      // Bước 5.11: Tạo Transaction 3 - Transfer In (category 18) cho _toSource
      // Số tiền nhận = amount (không bao gồm phí)
      final transferInRequest = TransactionRequest(
        amount: amount.toString(), // Đổi sang String để tránh precision error
        categoryId: 18, // Transfer In
        note: _noteController.text,
        transDate: _selectedDate!,
        reportable: true,
        sourceType: 1, // manual
        walletId: _toSource!.type == 'wallet' ? _toSource!.id : null,
        goalId: _toSource!.type == 'saving_goal' ? _toSource!.id : null,
      );

      final response3 = await TransactionService.create(transferInRequest);
      if (!response3.success) {
        throw Exception(response3.message ?? 'Failed to create transfer in transaction');
      }

      // Bước 5.12: Reload wallet/saving goal/transaction/budget để cập nhật số dư mới
      final walletProvider = context.read<WalletProvider>();
      final savingGoalProvider = context.read<SavingGoalProvider>();
      final transactionProvider = context.read<TransactionProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      
      await Future.wait(<Future<void>>[
        walletProvider.loadAll(context),
        savingGoalProvider.loadGoals(false, forceRefresh: true),
        transactionProvider.refresh(context),
        budgetProvider.refreshBudgets(),
      ]);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer successful')),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transfer failed: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// [6] Build UI màn hình chuyển tiền
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Money'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bước 6.1: Field chọn nguồn chuyển
            const Text(
              'From',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showSourcePicker(isFrom: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    if (_fromSource != null) ...[
                      _buildSourceIcon(_fromSource!),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        _fromSource?.name ?? 'Select source',
                        style: TextStyle(
                          color: _fromSource != null ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                    const Icon(Icons.unfold_more, color: Colors.grey),
                  ],
                ),
              ),
            ),
            if (_fromSource != null) ...[
              const SizedBox(height: 8),
              Text(
                'Balance: ${FormatHelper.formatVND(_fromSource!.balance)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],

            const SizedBox(height: 16),

            // Bước 6.2: Field chọn đích đến
            const Text(
              'To',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showSourcePicker(isFrom: false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    if (_toSource != null) ...[
                      _buildSourceIcon(_toSource!),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        _toSource?.name ?? 'Select destination',
                        style: TextStyle(
                          color: _toSource != null ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                    const Icon(Icons.unfold_more, color: Colors.grey),
                  ],
                ),
              ),
            ),
            if (_toSource != null) ...[
              const SizedBox(height: 8),
              Text(
                'Balance: ${FormatHelper.formatVND(_toSource!.balance)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],

            const SizedBox(height: 16),

            // Bước 6.3: Field nhập số tiền
            const Text(
              'Amount',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter amount',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),

            const SizedBox(height: 16),

            // Bước 6.4: Field phí chuyển khoản
            const Text(
              'Transfer Fee',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter fee (default: 0)',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),

            const SizedBox(height: 16),

            // Bước 6.5: Field ghi chú
            const Text(
              'Note',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Enter note (optional)',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            // Bước 6.6: Field chọn ngày
            const Text(
              'Date',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Select date',
                        style: TextStyle(
                          color: _selectedDate != null ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                    const Icon(Icons.unfold_more, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Bước 6.7: Nút chuyển tiền
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handleTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Transfer',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
