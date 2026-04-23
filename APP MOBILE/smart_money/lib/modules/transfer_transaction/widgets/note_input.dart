import 'package:flutter/material.dart';

class NoteInput extends StatelessWidget {
  final TextEditingController controller;

  const NoteInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        hintText: "Note",
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
