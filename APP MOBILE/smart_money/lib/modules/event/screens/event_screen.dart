import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../models/event_response.dart';
import 'add_event_screen.dart';
import 'event_detail_screen.dart'; // Import trang detail mới

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => EventScreenState();
}

class EventScreenState extends State<EventScreen> {
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EventProvider>(context, listen: false).loadEvents(false);
    });
  }

  void _changeTab(bool value) {
    setState(() => _isFinished = value);
    Provider.of<EventProvider>(context, listen: false).loadEvents(value);
  }

  // ITEM UI - Đã bỏ PopupMenu, thêm InkWell để click
  Widget _buildItem(EventResponse e) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailScreen(event: e)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.event, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.eventName ?? "No name",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "End: ${e.endDate ?? ''}",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EventProvider>(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text("Events", style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEventScreen()),
              );
              if (result == true && mounted) {
                provider.loadEvents(_isFinished, forceRefresh: true);
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildSegment(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                provider.clearCache();
                await provider.loadEvents(_isFinished);
              },
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.events.isEmpty
                  ? const Center(child: Text("No events", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                itemCount: provider.events.length,
                itemBuilder: (_, i) => _buildItem(provider.events[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          _segmentItem("Active", !_isFinished, () => _changeTab(false)),
          _segmentItem("Finished", _isFinished, () => _changeTab(true)),
        ],
      ),
    );
  }

  Widget _segmentItem(String title, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}