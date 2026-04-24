// modules/ai/screens/ai_chat_screen.dart
// AI Chat Screen - Chat với AI Assistant

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/ai_provider.dart';
import '../models/response/chat_history_item.dart';
import '../models/request/ai_chat_request.dart';
import '../../../modules/auth/providers/auth_provider.dart';
import 'dart:io';
import 'dart:convert';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

// Widget hiển thị dots animation cho typing indicator
class _TypingDotsAnimation extends StatefulWidget {
  const _TypingDotsAnimation();

  @override
  State<_TypingDotsAnimation> createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<_TypingDotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) {
              final delay = index * 0.2;
              final value = (_controller.value - delay) % 1.0;
              final scale = 0.5 + 0.5 * (1 - (value - 0.5).abs() * 2).clamp(0.0, 1.0);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DateFormat _timeFormat = DateFormat('dd/MM/yyyy HH:mm'); // Hiển thị đầy đủ ngày tháng năm giờ
  final ImagePicker _imagePicker = ImagePicker();

  // Speech to text
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  String _speechText = '';

  // Cache avatar user
  ImageProvider? _cachedUserAvatar;

  // Error message
  String? _errorMessage;

  // Show scroll to bottom button
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    // Cache avatar user
    _cachedUserAvatar = _getUserAvatar();
    // Bước 1: Load lịch sử chat khi mở screen
    Future.microtask(() async {
      await context.read<AiProvider>().loadHistory(context, refresh: true);
      // Scroll xuống cuối sau khi load xong
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });

    // Bước 1.1: Thêm scroll listener để load thêm khi kéo lên
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Bước 1.2: Xử lý scroll để load thêm khi kéo lên
  void _onScroll() {
    // Kiểm tra có nên hiện nút scroll xuống không
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Nếu scroll lên cách cuối > 300 pixels → hiện nút scroll xuống
    setState(() {
      _showScrollToBottom = maxScroll - currentScroll > 300;
    });

    if (currentScroll == maxScroll) {
      // Đã scroll đến cuối → không cần load thêm
      return;
    }

    // Khi scroll lên gần đầu (từ vị trí < 300 pixels) → load thêm
    if (currentScroll < 300 && currentScroll > 0) {
      final provider = context.read<AiProvider>();
      if (!provider.isLoading && provider.hasMore) {
        // Lưu vị trí scroll hiện tại
        final currentScrollPosition = currentScroll;

        // Load thêm messages
        provider.loadHistory(context, refresh: false);

        // Sau khi load xong, scroll lại vị trí cũ (để user không bị nhảy)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(currentScrollPosition + 100); // Tăng một chút để thấy tin nhắn mới
          }
        });
      }
    }
  }

  // Bước 2: Gửi tin nhắn
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    debugPrint('[SendMessage] Đang gửi tin nhắn: "$message"');
    if (message.isEmpty) {
      debugPrint('[SendMessage] Tin nhắn rỗng, không gửi');
      return;
    }

    _messageController.clear();
    setState(() {
      _errorMessage = null;
    });

    // Bước 2.1: Tạo request
    final request = AiChatRequest(message: message);

    // Bước 2.2: Gửi tin nhắn
    try {
      final provider = context.read<AiProvider>();
      await provider.sendMessage(context, request);
      debugPrint('[SendMessage] Đã gửi tin nhắn thành công');
      // Scroll xuống cuối tin nhắn mới
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      debugPrint('[SendMessage] Lỗi khi gửi: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to send message. Please try again.';
        });
      }
    }
  }

  // Bước 3: Scroll xuống cuối danh sách tin nhắn
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Bước 4: Xóa toàn bộ lịch sử
  Future<void> _clearHistory() async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text('Are you sure you want to delete all chat history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AiProvider>().clearHistory(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Không để keyboard đè chat
      backgroundColor: const Color(0xFF0D1117), // Màu nền tối đẹp
      appBar: AppBar(
        title: Row(
          children: [
            const Text('AI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            const Text('Online', style: TextStyle(fontSize: 10, color: Colors.greenAccent)),
          ],
        ),
        backgroundColor: const Color(0xFF161B22), // Màu AppBar tối
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          InkWell(
            onTap: _scanReceipt,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  const Icon(Icons.document_scanner_outlined, size: 16, color: Colors.greenAccent),
                  const SizedBox(width: 2),
                  const Text('OCR', style: TextStyle(fontSize: 9, color: Colors.greenAccent)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.greenAccent),
            onPressed: _clearHistory,
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Consumer<AiProvider>(
        builder: (context, provider, child) {
          // Bước 5: Hiển thị loading khi load lịch sử
          if (provider.isLoading && provider.chatHistory.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Bước 6: Hiển thị danh sách tin nhắn
          return Column(
            children: [
              Expanded(
                child: provider.chatHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'Start chatting with AI Assistant',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ask about transactions, reports, budgets, or upload receipts',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 24),
                            // Suggestion chips dựa trên 5 intent
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildSuggestionChip('Ăn trưa 50k'), // Intent 1: ADD_TRANSACTION
                                _buildSuggestionChip('Tháng này tiêu bao nhiêu?'), // Intent 2: REPORT
                                _buildSuggestionChip('Ngân sách tháng này'), // Intent 3: BUDGET
                                _buildSuggestionChip('Gợi ý kế hoạch chi tiêu'), // Intent 4: ADVISORY
                                _buildSuggestionChip('Nhắc tôi chuyển tiền vào ngày mai'), // Intent 5: REMIND_TASK
                              ],
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.chatHistory.length + 1 + (provider.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Hiển thị suggestion chips ở đầu danh sách
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildSuggestionChip('Ăn trưa 50k'),
                                  _buildSuggestionChip('Tháng này tiêu bao nhiêu?'),
                                  _buildSuggestionChip('Ngân sách tháng này'),
                                  _buildSuggestionChip('Gợi ý kế hoạch chi tiêu'),
                                  _buildSuggestionChip('Nhắc tôi chuyển tiền vào ngày mai'),
                                ],
                              ),
                            );
                          }

                          // Điều chỉnh index vì đã thêm suggestion chips
                          final adjustedIndex = index - 1;

                          // Hiển thị typing indicator ở cuối nếu đang loading
                          if (adjustedIndex == provider.chatHistory.length && provider.isLoading) {
                            return _buildTypingIndicator();
                          }

                          // Hiển thị theo thứ tự bình thường - tin nhắn cũ nhất ở trên cùng, mới nhất ở dưới cùng
                          if (adjustedIndex >= provider.chatHistory.length) return const SizedBox();

                          final message = provider.chatHistory[adjustedIndex];
                          return Column(
                            children: [
                              // Date separator
                              if (adjustedIndex == 0 || _isDifferentDay(message.createdAt, provider.chatHistory[adjustedIndex - 1].createdAt))
                                _buildDateSeparator(message.createdAt),
                              _buildMessageBubble(message),
                            ],
                          );
                        },
                      ),
              ),
              // Error banner
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 16),
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              // Bước 7: Input field để gửi tin nhắn
              _buildInputArea(provider),
              // Bước 7.1: Hiển thị indicator khi đang lắng nghe voice
              if (_isListening)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: const Color(0xFF2C2C2E),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Listening... $_speechText',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
        ),
      ),
      floatingActionButton: _showScrollToBottom
          ? FloatingActionButton(
              onPressed: _scrollToBottom,
              backgroundColor: const Color(0xFF238636),
              child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            )
          : null,
    );
  }

  // Bước 8: Build bubble tin nhắn
  Widget _buildMessageBubble(ChatHistoryItem message) {
    final isUser = !message.senderType; // false = User, true = AI
    final maxWidth = MediaQuery.of(context).size.width * 0.72;

    if (isUser) {
      // Chat user ở bên phải - iMessage style: góc bên phải vuông hơn
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Message bubble
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: const Color(0xFF238636), // Màu xanh dương GitHub
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hiển thị ảnh nếu có attachmentUrl
                if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: message.attachmentUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: double.infinity,
                        height: 150,
                        color: Colors.grey.shade800,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: double.infinity,
                        height: 150,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                // Hiển thị text message
                if (message.messageContent.isNotEmpty) ...[
                  if (message.attachmentUrl != null) const SizedBox(height: 8),
                  Text(
                    message.messageContent,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _timeFormat.format(message.createdAt),
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          // Icon user bên phải
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF238636),
              backgroundImage: _cachedUserAvatar,
            ),
          ),
        ],
      );
    } else {
      // Chat bot ở bên trái - iMessage style: góc bên trái vuông hơn
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon chat bot bên trái
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF21262D),
              backgroundImage: const AssetImage('assets/images/logo.png'),
            ),
          ),
          // Message bubble
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D), // Màu xám tối GitHub
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hiển thị ảnh nếu có attachmentUrl
                if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: message.attachmentUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: double.infinity,
                        height: 150,
                        color: Colors.grey.shade800,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: double.infinity,
                        height: 150,
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                // Hiển thị text message
                if (message.messageContent.isNotEmpty) ...[
                  if (message.attachmentUrl != null) const SizedBox(height: 8),
                  _buildMessageContent(message.messageContent),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(message.createdAt),
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  // Bước 8.9: Parse và format đẹp message content (xử lý JSON từ OCR)
  Widget _buildMessageContent(String content) {
    // Bước 8.9.1: Thử parse JSON
    try {
      final jsonData = jsonDecode(content);
      if (jsonData is Map<String, dynamic>) {
        // Bước 8.9.2: Nếu là JSON, format đẹp
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hiển thị note nếu có
            if (jsonData['note'] != null && jsonData['note'].toString().isNotEmpty) ...[
              Text(
                jsonData['note'].toString(),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
            ],
            // Hiển thị amount nếu có
            if (jsonData['amount'] != null) ...[
              Row(
                children: [
                  const Text('Amount: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(
                    jsonData['amount'].toString(),
                    style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            // Hiển thị category nếu có
            if (jsonData['category'] != null) ...[
              Row(
                children: [
                  const Text('Category: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(
                    jsonData['category'].toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            // Hiển thị date nếu có
            if (jsonData['date'] != null) ...[
              Row(
                children: [
                  const Text('Date: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(
                    jsonData['date'].toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ],
          ],
        );
      }
    } catch (e) {
      // Bước 8.9.3: Không phải JSON, hiển thị text bình thường
    }
    
    // Bước 8.9.4: Hiển thị text bình thường
    return Text(
      content,
      style: const TextStyle(color: Colors.white, fontSize: 14),
    );
  }

  // Bước 8.5: Lấy avatar của user từ AuthProvider
  ImageProvider? _getUserAvatar() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user?.avatarUrl != null && !user!.avatarUrl!.contains('svg')) {
      return NetworkImage(user.avatarUrl!);
    }
    return null;
  }

  // Bước 8.6: Format timestamp - hôm nay chỉ HH:mm, khác ngày full
  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day;
    if (isToday) {
      return DateFormat('HH:mm').format(dateTime);
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  // Bước 8.7: Kiểm tra khác ngày
  bool _isDifferentDay(DateTime date1, DateTime date2) {
    return date1.year != date2.year || date1.month != date2.month || date1.day != date2.day;
  }

  // Bước 8.8: Build date separator
  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (messageDate == today) {
      label = 'Today';
    } else if (messageDate == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('dd/MM/yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ),
    );
  }

  // Bước 8.9: Build suggestion chip
  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _messageController.text = text;
        _sendMessage();
      },
      backgroundColor: const Color(0xFF21262D),
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
      side: const BorderSide(color: Color(0xFF30363D)),
    );
  }

  // Bước 8.6: Typing indicator với dots animation
  Widget _buildTypingIndicator() {
    return Row(
      children: [
        // Icon chat bot bên trái
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF21262D),
            backgroundImage: const AssetImage('assets/images/logo.png'),
          ),
        ),
        // Dots animation
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: const _TypingDotsAnimation(),
        ),
      ],
    );
  }

  // Bước 9: Build input area
  Widget _buildInputArea(AiProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(top: const BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          // Bước 9.1: Nút upload ảnh
          IconButton(
            onPressed: () => _uploadImage(),
            icon: const Icon(Icons.image_outlined, color: Colors.greenAccent, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF21262D),
              minimumSize: const Size(36, 36),
            ),
          ),
          const SizedBox(width: 4),
          // Bước 9.2: Nút micro (voice input)
          IconButton(
            onPressed: () => _toggleVoiceInput(),
            icon: Icon(
              _isListening ? Icons.stop : Icons.mic_outlined,
              color: _isListening ? Colors.redAccent : Colors.greenAccent,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF21262D),
              minimumSize: const Size(36, 36),
            ),
          ),
          const SizedBox(width: 8),
          // Bước 9.3: TextField nhập tin nhắn
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: _isListening ? 'Đang nói...' : 'Nhập tin nhắn...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFF21262D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              onSubmitted: (_) => _sendMessage(),
              readOnly: _isListening,
            ),
          ),
          const SizedBox(width: 8),
          // Bước 9.5: Nút gửi tin nhắn
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _messageController.text.isNotEmpty ? const Color(0xFF238636) : const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: provider.isLoading ? null : _sendMessage,
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              style: IconButton.styleFrom(
                minimumSize: const Size(36, 36),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bước 10: Upload ảnh từ gallery
  Future<void> _uploadImage() async {
    // Bước 10.1: Xin quyền gallery
    final status = await Permission.photos.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo permission required for upload')),
      );
      return;
    }

    // Bước 10.2: Chọn ảnh từ gallery
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (!mounted || image == null) return;

    // Bước 10.3: Upload ảnh lên server
    final provider = context.read<AiProvider>();
    await provider.uploadReceipt(context, imagePath: image.path);

    // Bước 10.4: Scroll xuống cuối
    if (mounted) {
      _scrollToBottom();
    }
  }

  // Bước 10.5: Scan receipt với camera
  Future<void> _scanReceipt() async {
    // Bước 10.5.1: Xin quyền camera
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission required to scan receipt')),
      );
      return;
    }

    // Bước 10.5.2: Chụp ảnh với camera
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (!mounted || image == null) return;

    // Bước 10.5.3: Upload ảnh lên server để OCR
    final provider = context.read<AiProvider>();
    await provider.uploadReceipt(context, imagePath: image.path);

    // Bước 10.5.4: Scroll xuống cuối
    if (mounted) {
      _scrollToBottom();
    }
  }

  // Bước 11: Toggle voice input
  Future<void> _toggleVoiceInput() async {
    // Bước 11.1: Xin quyền microphone
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission required for voice input')),
      );
      return;
    }

    // Bước 11.2: Khởi tạo speech_to_text
    if (!_speechToText.isAvailable) {
      final available = await _speechToText.initialize();
      if (!mounted) return;
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device does not support voice input')),
        );
        return;
      }
    }

    // Bước 11.3: Bắt đầu hoặc dừng lắng nghe
    if (_isListening) {
      await _speechToText.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _isListening = true;
        _speechText = '';
      });
      debugPrint('[Speech] Bắt đầu lắng nghe...');

      try {
        await _speechToText.listen(
          onResult: (result) {
            debugPrint('[Speech] Result: ${result.recognizedWords}, final: ${result.finalResult}');
            if (!mounted) return;
            setState(() {
              // Bước 11.3.1: Update _speechText cho cả partial và final results
              _speechText = result.recognizedWords;
              // Bước 11.3.2: Update TextField realtime để người dùng thấy đang nói gì
              _messageController.text = _speechText;
              if (result.finalResult) {
                _isListening = false;
                debugPrint('[Speech] Kết thúc lắng nghe, text: $_speechText');
                // Chờ 1 giây trước khi auto send
                if (_speechText.trim().isNotEmpty) {
                  debugPrint('[Speech] Chờ 1 giây trước khi auto send');
                  Future.delayed(const Duration(seconds: 1), () {
                    if (!mounted) return;
                    debugPrint('[Speech] Gọi auto send với text: $_speechText');
                    _sendMessage();
                  });
                } else {
                  debugPrint('[Speech] Text rỗng, không auto send');
                }
              }
            });
          },
          listenOptions: stt.SpeechListenOptions(
            cancelOnError: true,
            partialResults: true,
            listenMode: stt.ListenMode.search, // Thử search mode thay vì dictation
            onDevice: false,
          ),
          localeId: 'vi_VN',
          listenFor: const Duration(seconds: 60), // Tăng lên 60s để có thời gian nói
          pauseFor: const Duration(seconds: 5), // Tăng lên 5s để không dừng quá nhanh
        );
      } catch (e) {
        debugPrint('[Speech] Lỗi khi lắng nghe: $e');
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      }
    }
  }
}
