// First, let's create a badge widget that we can reuse

// lib/widgets/notification_badge.dart
import 'package:flutter/material.dart';

class NotificationBadge extends StatelessWidget {
  final int count;
  final Color backgroundColor;
  final Color textColor;

  const NotificationBadge({
    Key? key,
    required this.count,
    this.backgroundColor = Colors.red,
    this.textColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink(); // Don't show badge if count is 0
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      child: Text(
        count > 10 ? '10+' : count.toString(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
