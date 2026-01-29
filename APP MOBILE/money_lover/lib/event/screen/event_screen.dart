import 'package:flutter/material.dart';
import 'package:money_lover/event/screen/add_event_screen.dart';


class EventScreen extends StatelessWidget {
  const EventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sự kiện"),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),

      // ✅ NÚT ADD CHUẨN MONEY LOVER
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEventScreen()),
          );
        },
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(),
          const SizedBox(height: 24),

          _eventItem(
            icon: Icons.flight,
            name: "Du lịch Đà Lạt",
            date: "01/03/2026 - 05/03/2026",
            spent: 3500000,
            budget: 5000000,
            color: Colors.blue,
          ),

          _eventItem(
            icon: Icons.cake,
            name: "Sinh nhật",
            date: "10/04/2026",
            spent: 1200000,
            budget: 2000000,
            color: Colors.pink,
          ),
        ],
      ),
    );
  }

  // ===== Widgets =====

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text("Tổng chi sự kiện", style: TextStyle(color: Colors.grey)),
          SizedBox(height: 8),
          Text(
            "4,700,000 đ",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _eventItem({
    required IconData icon,
    required String name,
    required String date,
    required int spent,
    required int budget,
    required Color color,
  }) {
    final percent = spent / budget;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                "${spent ~/ 1000}k / ${budget ~/ 1000}k",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
