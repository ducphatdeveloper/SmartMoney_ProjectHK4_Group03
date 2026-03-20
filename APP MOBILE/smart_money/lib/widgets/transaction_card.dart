
import 'package:flutter/material.dart';

class TransactionCard extends StatelessWidget {
  const TransactionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: const [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.money, color: Colors.white),
            ),
            title: Text("Trả nợ"),
            trailing: Text("9,000,000,000.00",
                style: TextStyle(color: Colors.red)),
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.money, color: Colors.white),
            ),
            title: Text("Đi vay"),
            trailing: Text("10,000,000,000.00",
                style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}
