import 'package:flutter/material.dart';

class BottomSaveButton extends StatelessWidget {
  final VoidCallback onSave;

  const BottomSaveButton({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: Colors.grey.shade700,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text("Save"),
        ),
      ),
    );
  }
}
