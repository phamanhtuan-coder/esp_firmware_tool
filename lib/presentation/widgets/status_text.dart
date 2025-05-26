import 'package:flutter/material.dart';

class StatusText extends StatelessWidget {
  final String status;
  final Color color;
  const StatusText({super.key, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      status,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}