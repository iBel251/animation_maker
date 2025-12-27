import 'package:flutter/material.dart';

class TimelinePanel extends StatelessWidget {
  const TimelinePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      width: double.infinity,
      color: Colors.grey.shade800,
      alignment: Alignment.center,
      child: const Text(
        'Timeline goes here',
        style: TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

