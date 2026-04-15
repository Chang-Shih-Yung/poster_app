import 'package:flutter/material.dart';

class PosterDetailPage extends StatelessWidget {
  const PosterDetailPage({super.key, required this.posterId});

  final String posterId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('海報 $posterId')),
      body: const Center(child: Text('海報詳情 (placeholder)')),
    );
  }
}
