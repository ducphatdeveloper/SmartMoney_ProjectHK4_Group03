
import 'package:flutter/material.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: CircleAvatar(child: Icon(Icons.arrow_upward)),
            title: Text("Trả nợ"),
            trailing: Text("-9,000,000,000", style: TextStyle(color: Colors.red)),
          ),
          ListTile(
            leading: CircleAvatar(child: Icon(Icons.arrow_downward)),
            title: Text("Đi vay"),
            trailing: Text("+10,000,000,000", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }
}
