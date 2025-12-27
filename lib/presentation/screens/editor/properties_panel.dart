import 'package:flutter/material.dart';

class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Colors.grey.shade100,
      child: const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Center(
            child: Text(
              'No object selected',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

