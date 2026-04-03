import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/helpers/token_helper.dart';
import '../providers/event_provider.dart';
import 'add_event_screen.dart';
import 'event_list_view.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => EventScreenState();
}

class EventScreenState extends State<EventScreen> {
  bool _isFinished = false;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final token = await TokenHelper.getAccessToken();
    if (mounted) {
      setState(() => _accessToken = token);
      _refreshData();
    }
  }

  void _refreshData() {
    Provider.of<EventProvider>(context, listen: false).loadEvents(_isFinished);
  }

  void _changeTab(bool value) {
    if (_isFinished == value) return;
    setState(() => _isFinished = value);
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("My Events", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEventScreen()));
                if (res == true) _refreshData();
              },
              icon: const Icon(Icons.add_circle, color: Colors.greenAccent, size: 32),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          _buildSegment(),
          Expanded(
            child: (_accessToken == null)
                ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                : EventListView(accessToken: _accessToken),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      height: 50,
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
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
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isActive ? const Color(0xFF2C2C2E) : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(title, style: TextStyle(color: isActive ? Colors.greenAccent : Colors.grey, fontWeight: isActive ? FontWeight.w900 : FontWeight.w500)),
        ),
      ),
    );
  }
}