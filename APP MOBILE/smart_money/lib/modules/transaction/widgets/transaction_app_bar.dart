import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/transaction/dialogs/date_range_mode_dialog.dart';
import 'package:smart_money/modules/ai/screens/ai_chat_screen.dart';
import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';

/// AppBar cho Transaction List Screen
class TransactionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onSearchPressed;

  const TransactionAppBar({
    super.key,
    required this.onSearchPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black87,
      elevation: 0,
      leading: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Transaction List'),
              content: const Text(
                'View and manage your transactions. Switch between different wallets/goals, filter by date range, and search for specific transactions.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.info_outline, color: Colors.white70, size: 18),
        ),
      ),
      title: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          return _buildSourceDropdown(context, provider);
        },
      ),
      centerTitle: true,
      actions: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AiChatScreen(),
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(
                  image: AssetImage('assets/icons/ai.png'),
                  width: 22,
                  height: 22,
                ),
                SizedBox(width: 2),
                Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white70),
          onPressed: onSearchPressed,
        ),
        _buildPopupMenu(context),
      ],
    );
  }

  /// Dropdown button chọn ví/mục tiêu (dùng CachedNetworkImage + fallback icon)
  Widget _buildSourceDropdown(BuildContext context, TransactionProvider provider) {
    return SizedBox(
      width: 180,
      child: GestureDetector(
        onTap: () => _showSourceBottomSheet(context, provider),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon ví từ URL — convert filename thành Cloudinary URL nếu cần
              _buildDropdownIcon(provider.selectedSource.iconUrl, provider.selectedSource.type),
              
              if (provider.selectedSource.iconUrl != null && 
                  provider.selectedSource.iconUrl!.isNotEmpty)
                const SizedBox(width: 8)
              else if (provider.selectedSource.type == 'all')
                const SizedBox(width: 8)
              else
                const SizedBox.shrink(),
              
              // Tên ví
              Expanded(
                child: Text(
                  provider.selectedSource.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.unfold_more, color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  /// Build icon cho dropdown — convert URL nếu cần
  Widget _buildDropdownIcon(String? iconUrl, String type) {
    final cloudinaryUrl = IconHelper.buildCloudinaryUrl(iconUrl);
    
    if (cloudinaryUrl != null && cloudinaryUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cloudinaryUrl,
        width: 24,
        height: 24,
        fit: BoxFit.cover,
        placeholder: (context, url) => const SizedBox(width: 24, height: 24),
        errorWidget: (context, url, error) => _buildDropdownDefaultIcon(type),
      );
    }
    
    return _buildDropdownDefaultIcon(type);
  }

  /// Default icon nhỏ cho dropdown (khi URL fail hoặc "Tổng cộng")
  Widget _buildDropdownDefaultIcon(String type) {
    if (type == 'all') {
      return const Icon(Icons.account_balance_wallet, color: Colors.green, size: 18);
    } else if (type == 'saving_goal') {
      return const Icon(Icons.savings, color: Colors.orange, size: 18);
    } else {
      return const Icon(Icons.account_balance_wallet, color: Colors.green, size: 18);
    }
  }


  /// Menu 3 chấm
  Widget _buildPopupMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white70),
      color: Colors.grey[850],
      onSelected: (value) async {
        final provider = context.read<TransactionProvider>();
        switch (value) {
          case 'journal':
            if (provider.isGroupedMode) await provider.toggleViewMode(context);
            break;
          case 'grouped':
            if (!provider.isGroupedMode) await provider.toggleViewMode(context);
            break;
          case 'time_period':
            showDialog(
              context: context,
              builder: (_) => const DateRangeModeDialog(),
            );
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'journal',
          child: Row(
            children: [
              Icon(Icons.view_list, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('View by journal', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'grouped',
          child: Row(
            children: [
              Icon(Icons.category, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('View by group', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'time_period',
          child: Row(
            children: [
              Icon(Icons.date_range, color: Colors.white70, size: 20),
              SizedBox(width: 12),
              Text('Time period', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  /// Bottom sheet chọn ví (dùng CachedNetworkImage + fallback icon)
  void _showSourceBottomSheet(BuildContext context, TransactionProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return ListView.builder(
          itemCount: provider.sourceItems.length,
          itemBuilder: (context, index) {
            final item = provider.sourceItems[index];
            final isSelected = item.id == provider.selectedSource.id &&
                item.type == provider.selectedSource.type;

            return ListTile(
              // Icon từ URL — convert filename thành Cloudinary URL nếu cần
              leading: _buildSourceSheetIcon(item),
              title: Text(
                item.name,
                style: TextStyle(
                  color: isSelected ? Colors.green : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: item.balance != null
                  ? Text(
                      FormatHelper.formatVND(item.balance),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    )
                  : null,
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () {
                provider.selectSource(context, item);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  /// Build icon cho sheet — convert URL nếu cần
  Widget _buildSourceSheetIcon(dynamic item) {
    final cloudinaryUrl = IconHelper.buildCloudinaryUrl(item.iconUrl);
    
    if (cloudinaryUrl != null && cloudinaryUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cloudinaryUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildDefaultSourceIcon(item),
        errorWidget: (context, url, error) => _buildDefaultSourceIcon(item),
      );
    }
    
    return _buildDefaultSourceIcon(item);
  }

  Widget _buildDefaultSourceIcon(dynamic item) {
    IconData iconData;
    Color bgColor;

    if (item.type == 'saving_goal') {
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

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

