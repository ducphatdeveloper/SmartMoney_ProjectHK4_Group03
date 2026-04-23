
import 'package:flutter/material.dart';

class PromoCard extends StatelessWidget {
  const PromoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.green, Colors.teal],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: const [
          Expanded(
            child: Text(
              "Have you enjoyed Premium yet?\nMaximize benefits while Premium is free",
              style: TextStyle(color: Colors.white),
            ),
          ),
          Icon(Icons.arrow_forward, color: Colors.white),
        ],
      ),
    );
  }
}
