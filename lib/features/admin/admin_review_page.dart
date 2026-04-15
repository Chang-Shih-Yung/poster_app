import 'package:flutter/material.dart';

class AdminReviewPage extends StatelessWidget {
  const AdminReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin 審核')),
      body: const Center(child: Text('待審核清單 (placeholder)')),
    );
  }
}
