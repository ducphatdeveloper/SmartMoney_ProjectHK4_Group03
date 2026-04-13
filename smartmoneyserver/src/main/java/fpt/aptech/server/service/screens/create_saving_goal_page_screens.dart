import 'package:flutter/material.dart';

class CreateSavingGoalPage extends StatelessWidget {
  const CreateSavingGoalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final targetController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo ví tiết kiệm')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Mục tiêu tiết kiệm',
                prefixIcon: Icon(Icons.savings),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số tiền mục tiêu',
                prefixIcon: Icon(Icons.flag),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('TẠO MỤC TIÊU'),
            ),
          ],
        ),
      ),
    );
  }
}
